#!/bin/bash
# 清理 KnowledgeBit App Group 資料庫的腳本

echo "正在尋找 KnowledgeBit App Group 資料夾..."

# 找到所有模擬器設備
DEVICES_DIR="$HOME/Library/Developer/CoreSimulator/Devices"

if [ ! -d "$DEVICES_DIR" ]; then
    echo "❌ 找不到模擬器設備資料夾"
    exit 1
fi

# 尋找 App Group 資料夾
FOUND=false
for DEVICE_DIR in "$DEVICES_DIR"/*/; do
    APP_GROUP_DIR="$DEVICE_DIR/data/Containers/Shared/AppGroup/group.com.timmychen.KnowledgeBit"
    
    if [ -d "$APP_GROUP_DIR" ]; then
        echo "✅ 找到 App Group 資料夾: $APP_GROUP_DIR"
        FOUND=true
        
        # 列出所有資料庫相關檔案
        echo ""
        echo "資料庫檔案："
        ls -lah "$APP_GROUP_DIR" | grep -E "\.(store|sqlite)"
        
        echo ""
        read -p "是否要刪除這些資料庫檔案？(y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 刪除所有資料庫檔案
            rm -f "$APP_GROUP_DIR"/*.store
            rm -f "$APP_GROUP_DIR"/*.sqlite
            rm -f "$APP_GROUP_DIR"/*.sqlite-wal
            rm -f "$APP_GROUP_DIR"/*.sqlite-shm
            echo "✅ 已刪除資料庫檔案"
        else
            echo "取消操作"
        fi
        
        break
    fi
done

if [ "$FOUND" = false ]; then
    echo "❌ 找不到 App Group 資料夾"
    echo "請確保："
    echo "1. 已經運行過 App（至少一次）"
    echo "2. App Group ID 正確：group.com.timmychen.KnowledgeBit"
    echo ""
    echo "或者直接在模擬器/裝置上刪除 App 並重新安裝"
fi
