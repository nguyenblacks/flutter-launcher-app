import os
import requests
import time

OUTPUT_DIR = "assets/wallpapers"

def download_wallpapers():
    # Clean output directory
    if os.path.exists(OUTPUT_DIR):
        import shutil
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR)
        
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
    }
    
    print("Starting download of 90 high-quality wallpapers...")
    
    count = 1
    for i in range(1, 91):
        # picsum.photos serves high quality images from Unsplash, cropped to 1080x1920
        img_url = f"https://picsum.photos/1080/1920?random={i}"
        file_path = os.path.join(OUTPUT_DIR, f"wallpaper_{count}.jpg")
        
        try:
            img_res = requests.get(img_url, headers=headers, timeout=15)
            if img_res.status_code == 200:
                with open(file_path, 'wb') as f:
                    f.write(img_res.content)
                print(f"Downloaded [{count}/90]: {file_path}")
                count += 1
                # Small sleep to prevent rate limiting
                time.sleep(0.1)
            else:
                print(f"Failed to fetch photo (random={i}): status {img_res.status_code}")
        except Exception as e:
            print(f"Error downloading wallpaper {i}: {e}")
            
    print("Done downloading wallpapers.")

if __name__ == "__main__":
    download_wallpapers()
