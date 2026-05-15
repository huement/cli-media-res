import os
import uuid
import subprocess
import sys
import argparse
import yaml
import cv2
import numpy as np
import skvideo.io

try:
    import tensorflow.compat.v1 as tf
except ImportError:
    import tensorflow as tf

import network
import guided_filter

class WB_Cartoonize:
    def __init__(self, weights_dir, gpu):
        if not os.path.exists(weights_dir):
            raise FileNotFoundError(f"Weights Directory not found at: {weights_dir}")
        self.load_model(weights_dir, gpu)
        print("✅ Weights successfully loaded")
    
    def resize_crop(self, image, config):
        h, w, c = np.shape(image)
        # Only resize if the config says so
        if not config.get('original_resolution', True):
            resize_dim = config.get('resize-dim', 720)
            if min(h, w) > resize_dim:
                if h > w:
                    h, w = int(resize_dim * h / w), resize_dim
                else:
                    h, w = resize_dim, int(resize_dim * w / h)
                image = cv2.resize(image, (w, h), interpolation=cv2.INTER_AREA)
        
        # U-Net requires dimensions to be divisible by 8
        h, w = (h // 8) * 8, (w // 8) * 8
        image = image[:h, :w, :]
        return image

    def load_model(self, weights_dir, gpu):
        tf.disable_eager_execution()
        tf.reset_default_graph()
        
        self.input_photo = tf.placeholder(tf.float32, [1, None, None, 3], name='input_image')
        network_out = network.unet_generator(self.input_photo)
        self.final_out = guided_filter.guided_filter(self.input_photo, network_out, r=1, eps=5e-3)

        gene_vars = [var for var in tf.trainable_variables() if 'generator' in var.name]
        saver = tf.train.Saver(var_list=gene_vars)
        
        config = tf.ConfigProto(gpu_options=tf.GPUOptions(allow_growth=True) if gpu else None,
                                device_count={'GPU': 1 if gpu else 0})
        
        self.sess = tf.Session(config=config)
        self.sess.run(tf.global_variables_initializer())
        saver.restore(self.sess, tf.train.latest_checkpoint(weights_dir))

    def infer(self, image, config):
        image = self.resize_crop(image, config)
        batch_image = image.astype(np.float32) / 127.5 - 1
        batch_image = np.expand_dims(batch_image, axis=0)
        
        output = self.sess.run(self.final_out, feed_dict={self.input_photo: batch_image})
        
        output = (np.squeeze(output) + 1) * 127.5
        return np.clip(output, 0, 255).astype(np.uint8)
    
    def process_video(self, input_path, output_path, config):
        cap = cv2.VideoCapture(input_path)
        fps = cap.get(cv2.CAP_PROP_FPS) if config.get('original_frame_rate') else eval(config.get('output_frame_rate', '24/1'))
        target_size = (int(cap.get(3)), int(cap.get(4)))
        
        temp_out = f"temp_{uuid.uuid4().hex[:8]}.mp4"
        writer = skvideo.io.FFmpegWriter(temp_out, inputdict={'-r': str(fps)}, outputdict={'-r': str(fps)})

        print(f"🎬 Processing: {os.path.basename(input_path)}")
        while True:
            ret, frame = cap.read()
            if not ret: break
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = self.infer(frame, config)
            # Ensure output matches target size if we cropped for the U-Net
            if frame.shape[1] != target_size[0] or frame.shape[0] != target_size[1]:
                frame = cv2.resize(frame, target_size)
            writer.writeFrame(frame)
        
        cap.release()
        writer.close()

        print(f"🔊 Merging audio and finalizing...")
        subprocess.run([
            'ffmpeg', '-y', '-i', temp_out, '-i', input_path,
            '-map', '0:v:0', '-map', '1:a:0?', 
            '-c:v', 'libx264', '-c:a', 'copy', 
            '-pix_fmt', 'yuv420p', '-shortest', output_path
        ], check=True, capture_output=True)

        os.remove(temp_out)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, help='Path to input video')
    parser.add_argument('--output', required=True, help='Path to output video')
    args = parser.parse_args()

    # Determine script directory for relative pathing
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Load config.yaml
    with open(os.path.join(script_dir, 'config.yaml'), 'r') as f:
        config = yaml.safe_load(f)

    # Init and Run
    wbc = WB_Cartoonize(os.path.join(script_dir, 'saved_models'), config.get('gpu', True))
    wbc.process_video(args.input, args.output, config)
    print(f"✨ Success: {args.output}")