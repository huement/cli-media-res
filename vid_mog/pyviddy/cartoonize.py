#!/usr/bin/env python3
"""AI Cartoonizer & Media Suite for PyWocky.

Multi-engine video cartoonization pipeline supporting:
- AI: Neural Guided Filter (TensorFlow White-Box Cartoonization)
- Recipe: FFmpeg fast color quantization & bilateral edge smoothing
- Frei0r: FFmpeg retro frei0r cartoon filtering with dynamic intensity thresholding
- Shader: MPV / GLSL GPU Shader rendering using presets in ./vid_mog/glsl/
"""

import argparse
import os
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


def get_tensorflow() -> Optional[Any]:
    """Lazily imports TensorFlow to allow non-AI engines to run without TF dependencies."""
    try:
        import tensorflow.compat.v1 as tf

        tf.disable_eager_execution()
        return tf
    except ImportError:
        try:
            import tensorflow as tf

            return tf
        except ImportError:
            return None


def get_cv2() -> Optional[Any]:
    """Lazily imports OpenCV to allow non-vision modes to execute without cv2 installed."""
    try:
        import cv2

        return cv2
    except ImportError:
        return None


def get_video_dimensions(file_path: Path) -> Tuple[int, int]:
    """Queries input video dimensions via ffprobe with OpenCV fallback defaults."""
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height",
        "-of",
        "csv=s=x:p=0",
        str(file_path),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        dims = result.stdout.strip().split("x")
        if len(dims) == 2:
            return int(dims[0]), int(dims[1])
    except Exception:
        pass

    cv2_lib = get_cv2()
    if cv2_lib is not None:
        try:
            cap = cv2_lib.VideoCapture(str(file_path))
            w = int(cap.get(cv2_lib.CAP_PROP_FRAME_WIDTH))
            h = int(cap.get(cv2_lib.CAP_PROP_FRAME_HEIGHT))
            cap.release()
            if w > 0 and h > 0:
                return w, h
        except Exception:
            pass

    return 1280, 720


def normalize_intensity(raw_val: float) -> float:
    """Normalizes raw intensity whether supplied as an integer (1-100) or float (0.0-1.0)."""
    norm = raw_val / 100.0 if raw_val > 1.0 else raw_val
    return max(0.01, min(1.0, norm))


class WB_Cartoonize:
    """TensorFlow White-Box Cartoonization Engine."""

    def __init__(
        self,
        weights_dir: str,
        gpu: bool,
        r: int = 1,
        eps: float = 5e-3,
        delta: float = 1.0,
    ) -> None:
        self.cv2 = get_cv2()
        if self.cv2 is None:
            raise RuntimeError(
                "OpenCV (opencv-python) is required for 'ai' mode. "
                "Run using PyWocky or the dedicated venv at vid_mog/pyviddy/venv/bin/python"
            )

        self.tf = get_tensorflow()
        if self.tf is None:
            raise RuntimeError(
                "TensorFlow is required for 'ai' mode. Ensure it is installed in vid_mog/pyviddy/venv."
            )

        import guided_filter
        import network

        self.guided_filter = guided_filter
        self.network = network

        if not os.path.exists(weights_dir):
            raise FileNotFoundError(
                f"Weights Directory not found at: {weights_dir}"
            )

        self.load_model(weights_dir, gpu, r, eps, delta)
        print("✅ TensorFlow Neural Weights successfully loaded")

    def resize_crop(self, image: Any, config: Dict[str, Any]) -> Any:
        import numpy as np

        h, w, _ = np.shape(image)
        if not config.get("original_resolution", True):
            resize_dim = config.get("resize-dim", 720)
            if min(h, w) > resize_dim:
                if h > w:
                    h, w = int(resize_dim * h / w), resize_dim
                else:
                    h, w = resize_dim, int(resize_dim * w / h)
                image = self.cv2.resize(
                    image, (w, h), interpolation=self.cv2.INTER_AREA
                )

        h, w = (h // 8) * 8, (w // 8) * 8
        return image[:h, :w, :]

    def load_model(
        self,
        weights_dir: str,
        gpu: bool,
        r: int,
        eps: float,
        delta: float,
    ) -> None:
        self.tf.reset_default_graph()

        self.input_photo = self.tf.placeholder(
            self.tf.float32, [1, None, None, 3], name="input_image"
        )

        network_out = self.network.unet_generator(self.input_photo)
        filtered_out = self.guided_filter.guided_filter(
            self.input_photo, network_out, r=r, eps=eps
        )
        self.final_out = delta * filtered_out + (1 - delta) * network_out

        gene_vars = [
            var
            for var in self.tf.trainable_variables()
            if "generator" in var.name
        ]
        saver = self.tf.train.Saver(var_list=gene_vars)

        config = self.tf.ConfigProto(
            gpu_options=(
                self.tf.GPUOptions(allow_growth=True) if gpu else None
            ),
            device_count={"GPU": 1 if gpu else 0},
        )

        self.sess = self.tf.Session(config=config)
        self.sess.run(self.tf.global_variables_initializer())
        saver.restore(self.sess, self.tf.train.latest_checkpoint(weights_dir))

    def infer(self, image: Any, config: Dict[str, Any]) -> Any:
        import numpy as np

        image = self.resize_crop(image, config)
        batch_image = image.astype(np.float32) / 127.5 - 1
        batch_image = np.expand_dims(batch_image, axis=0)
        output = self.sess.run(
            self.final_out, feed_dict={self.input_photo: batch_image}
        )
        output = (np.squeeze(output) + 1) * 127.5
        return np.clip(output, 0, 255).astype(np.uint8)

    def process_video(
        self, input_path: str, output_path: str, config: Dict[str, Any]
    ) -> None:
        import skvideo.io

        cap = self.cv2.VideoCapture(input_path)
        fps = (
            cap.get(self.cv2.CAP_PROP_FPS)
            if config.get("original_frame_rate")
            else eval(config.get("output_frame_rate", "24/1"))
        )
        target_size = (int(cap.get(3)), int(cap.get(4)))

        temp_out = f"temp_{uuid.uuid4().hex[:8]}.mp4"
        writer = skvideo.io.FFmpegWriter(
            temp_out,
            inputdict={"-r": str(fps)},
            outputdict={"-r": str(fps)},
        )

        while True:
            ret, frame = cap.read()
            if not ret:
                break
            frame = self.cv2.cvtColor(frame, self.cv2.COLOR_BGR2RGB)
            frame = self.infer(frame, config)
            if (
                frame.shape[1] != target_size[0]
                or frame.shape[0] != target_size[1]
            ):
                frame = self.cv2.resize(frame, target_size)
            writer.writeFrame(frame)

        cap.release()
        writer.close()

        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                temp_out,
                "-i",
                input_path,
                "-map",
                "0:v:0",
                "-map",
                "1:a:0?",
                "-c:v",
                "libx264",
                "-c:a",
                "copy",
                "-pix_fmt",
                "yuv420p",
                "-shortest",
                output_path,
            ],
            check=True,
            capture_output=True,
        )
        if os.path.exists(temp_out):
            os.remove(temp_out)


def process_ffmpeg_recipe(input_path: str, output_path: str) -> None:
    """FFmpeg recipe mode: Fast bilateral edge smoothing and color quantization."""
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        input_path,
        "-vf",
        "smartblur=lr=2.0:ls=-0.9:lt=-5.0:cr=0.5:cs=1.0:ct=1.5,eq=contrast=1.2:saturation=1.4",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "copy",
        output_path,
    ]
    subprocess.run(cmd, check=True)


def process_frei0r(input_path: str, output_path: str, raw_intensity: float = 80.0) -> None:
    """Frei0r filter mode: Retro cartoon outline pass.

    Requires explicit RGB24 color space negotiation for Frei0r and an optimal
    edge threshold (0.70 to 0.99) mapped from normalized intensity to prevent blackouts.
    """
    norm = normalize_intensity(raw_intensity)
    threshold = 0.70 + (norm * 0.29)
    threshold_str = f"{threshold:.4f}"

    print(f"🎬 Processing Frei0r Cartoon (Intensity: {raw_intensity:.0f}% -> Threshold: {threshold_str})")

    vf_pipeline = (
        f"format=rgb24,"
        f"frei0r=filter_name=cartoon:filter_params={threshold_str},"
        f"format=yuv420p"
    )

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        input_path,
        "-vf",
        vf_pipeline,
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "copy",
        output_path,
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Frei0r filter render failed: {e}")
        sys.exit(1)


def resolve_shader_path(shader_input: Optional[str], script_dir: str) -> str:
    """Resolves GLSL shader file location from direct paths or ./vid_mog/glsl/ directory."""
    if not shader_input:
        raise ValueError("Shader mode requires a GLSL shader selection.")

    candidate = Path(shader_input)
    if candidate.exists():
        return str(candidate.resolve())

    glsl_dir = Path(script_dir).parent / "glsl"
    fallback = glsl_dir / candidate.name
    if fallback.exists():
        return str(fallback.resolve())

    raise FileNotFoundError(
        f"GLSL Shader file not found at '{shader_input}' or '{fallback}'"
    )


def process_shader(
    input_path: str, output_path: str, shader_input: Optional[str], script_dir: str
) -> None:
    """GLSL GPU Shader mode via MPV rendering with GPU filter graph activation."""
    resolved_shader = resolve_shader_path(shader_input, script_dir)
    width, height = get_video_dimensions(Path(input_path))

    print(
        f"🎨 Applying GLSL Shader ({width}x{height}): {Path(resolved_shader).name}"
    )

    cmd = [
        "mpv",
        input_path,
        f"--vf=gpu=w={width}:h={height}",
        f"--glsl-shader={resolved_shader}",
        f"--o={output_path}",
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ MPV GLSL shader render failed: {e}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Cartoonizer & Media Suite")
    parser.add_argument("--input", required=True, help="Input video file path")
    parser.add_argument(
        "--mode",
        choices=["ai", "recipe", "frei0r", "shader"],
        default="ai",
        help="Core processing engine",
    )
    parser.add_argument(
        "--output", required=False, default=None, help="Output video file path"
    )
    parser.add_argument(
        "--shader",
        required=False,
        default=None,
        help="GLSL shader path or filename in ./vid_mog/glsl/",
    )
    parser.add_argument(
        "--radius", type=int, default=1, help="AI guided filter radius"
    )
    parser.add_argument(
        "--eps", type=float, default=5e-3, help="AI epsilon smoothing"
    )
    parser.add_argument(
        "--intensity",
        type=float,
        default=80.0,
        help="Stylization intensity or threshold (1 to 100)",
    )

    args = parser.parse_args()
    script_dir = os.path.dirname(os.path.abspath(__file__))

    norm_intensity = normalize_intensity(args.intensity)

    if args.output is None:
        base_dir = os.path.dirname(args.input)
        filename = os.path.basename(args.input)
        name, ext = os.path.splitext(filename)

        if args.mode == "ai":
            suffix = f"_cartoon_r{args.radius}_eps{args.eps}_int{norm_intensity:.2f}"
        elif args.mode == "shader" and args.shader:
            shader_name = Path(args.shader).stem
            suffix = f"_cartoon_shader_{shader_name}"
        else:
            suffix = f"_cartoon_{args.mode}_int{int(args.intensity)}"

        args.output = os.path.join(base_dir, f"{name}{suffix}{ext}")

    print(f"🚀 Launching Cartoonizer Pipeline [Engine: {args.mode.upper()}]")

    if args.mode == "ai":
        import yaml

        config_path = os.path.join(script_dir, "config.yaml")
        config: Dict[str, Any] = {}
        if os.path.exists(config_path):
            with open(config_path, "r") as f:
                config = yaml.safe_load(f) or {}

        wbc = WB_Cartoonize(
            os.path.join(script_dir, "saved_models"),
            config.get("gpu", True),
            r=args.radius,
            eps=args.eps,
            delta=norm_intensity,
        )
        wbc.process_video(args.input, args.output, config)

    elif args.mode == "recipe":
        process_ffmpeg_recipe(args.input, args.output)

    elif args.mode == "frei0r":
        process_frei0r(args.input, args.output, args.intensity)

    elif args.mode == "shader":
        process_shader(args.input, args.output, args.shader, script_dir)

    print(f"✨ Success: {args.output}")


if __name__ == "__main__":
    main()