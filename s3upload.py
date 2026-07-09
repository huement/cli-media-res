import os
import sys
import argparse
import mimetypes
import boto3
from botocore.config import Config

# Ensure modern web formats like webp are correctly registered for content-type guessing
mimetypes.add_type('image/webp', '.webp')

print("Initializing Python Cloud Sync Engine...", flush=True)

# 1. Setup Request Timeout & Retry Policies
config = Config(
    connect_timeout=10,
    read_timeout=10,
    retries={'max_attempts': 3}
)

# 2. Simple Custom .env Parser (avoids needing extra pip installs)
def load_env_variables():
    env_vars = {}
    if os.path.exists('.env'):
        with open('.env', 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, val = line.split('=', 1)
                    env_vars[key.strip()] = val.strip().strip('"').strip("'")
    return env_vars

env = load_env_variables()

# 3. Establish Config Hierarchy (Environment Variables/ .env -> Fallback Hardcoded Defaults)
ENDPOINT_URL = env.get('AWS_ENDPOINT', 'https://s3-api.example.com')
ACCESS_KEY = env.get('AWS_ACCESS_KEY_ID', '<ACCESS KEY>')
SECRET_KEY = env.get('AWS_SECRET_ACCESS_KEY', '<SECRET KEY>')
BUCKET_NAME = env.get('AWS_BUCKET', 'bucket-name')
DEFAULT_REMOTE_DIR = env.get('S3_REMOTE_DIR', 'images')

# 4. Instantiate the Boto3 S3 Resource Connection
s3_client = boto3.client(
    's3',
    endpoint_url=ENDPOINT_URL,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    config=config
)

def upload_directory(local_dir, target_extension=None, remote_prefix=None):
    if not os.path.isdir(local_dir):
        print(f"[ERROR] Target path '{local_dir}' is not a valid directory.")
        sys.exit(1)

    # Sanitize remote folder prefix pathing rules
    remote_dir = remote_prefix if remote_prefix is not None else DEFAULT_REMOTE_DIR
    remote_dir = remote_dir.strip('/')

    print(f"\n==========================================")
    print(f"Target Directory: {local_dir}")
    print(f"Extension Filter: {f'.{target_extension}' if target_extension else 'None (All Files)'}")
    print(f"Remote Path Target: s3://{BUCKET_NAME}/{remote_dir}/")
    print(f"==========================================\n")

    success_count = 0
    fail_count = 0

    # Walk the filesystem recursively
    for root, _, files in os.walk(local_dir):
        for file in files:
            # Apply the extension filter constraint if declared
            if target_extension:
                if not file.lower().endswith(f".{target_extension.lower()}"):
                    continue

            local_file_path = os.path.join(root, file)
            
            # Calculate structural relative paths matching the target layout
            relative_path = os.path.relpath(local_file_path, local_dir)
            
            # Form final key path structure inside the object bucket
            if remote_dir:
                s3_key = f"{remote_dir}/{relative_path}".replace('\\', '/')
            else:
                s3_key = relative_path.replace('\\', '/')

            # Guess content-type metadata so images open in browser properly
            content_type, _ = mimetypes.guess_type(local_file_path)
            if not content_type:
                content_type = 'application/octet-stream'

            print(f"📦 Uploading: {relative_path} -> {s3_key} [{content_type}]", flush=True)

            try:
                s3_client.upload_file(
                    Filename=local_file_path,
                    Bucket=BUCKET_NAME,
                    Key=s3_key,
                    ExtraArgs={'ContentType': content_type}
                )
                success_count += 1
            except Exception as e:
                print(f"❌ Failed to upload {file}: {e}", flush=True)
                fail_count += 1

    print(f"\n==========================================")
    print(f"⚡ Sync Complete! Successfully uploaded: {success_count} files.")
    if fail_count > 0:
        print(f"⚠️ Failures encountered: {fail_count} files.")
    print(f"==========================================\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pure Python S3/MinIO Folder Sync Engine")
    parser.add_argument("directory", help="The local directory path to scan and sync")
    parser.add_argument("--extension", help="Filter target files by a specific extension type (e.g. webp, png, jpg)", default=None)
    parser.add_argument("--remote-dir", help="Override destination folder path prefix inside bucket", default=None)
    
    args = parser.parse_args()
    
    # Strip leading dot from extension argument if accidentally supplied by user
    ext_filter = args.extension.lstrip('.') if args.extension else None
    
    upload_directory(
        local_dir=args.directory,
        target_extension=ext_filter,
        remote_prefix=args.remote_dir
    )