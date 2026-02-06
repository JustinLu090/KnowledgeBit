# Supabase Storage 設定指南

## 儲存用戶頭貼圖片

由於 `avatarData` 是二進位資料，建議使用 Supabase Storage 來儲存圖片，而不是直接存在 PostgreSQL 資料庫中。

## 設定步驟

### 1. 在 Supabase Dashboard 創建 Storage Bucket

1. 前往 Supabase Dashboard > Storage
2. 點擊 "New bucket"
3. 設定：
   - **Name**: `user-avatars`
   - **Public bucket**: ✅ 勾選（如果希望公開訪問）
   - **File size limit**: 5 MB（建議）
   - **Allowed MIME types**: `image/jpeg, image/png, image/webp`

### 2. 設定 Storage Policies

在 Storage > Policies 中，為 `user-avatars` bucket 設定以下政策：

#### 查看政策（Select）
```sql
-- 允許所有人查看頭貼（如果是公開 bucket）
-- 或只允許登入用戶查看：
CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'user-avatars');
```

#### 上傳政策（Insert）
```sql
-- 用戶只能上傳自己的頭貼
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'user-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

#### 更新政策（Update）
```sql
-- 用戶只能更新自己的頭貼
CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'user-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

#### 刪除政策（Delete）
```sql
-- 用戶只能刪除自己的頭貼
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'user-avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

### 3. 檔案路徑結構

建議使用以下路徑結構：
```
user-avatars/
  {user_id}/
    avatar.jpg
```

例如：`user-avatars/4208E310-A7B9-4EF3-A943-A3A4FF114BDB/avatar.jpg`

### 4. 在 App 中使用

上傳頭貼到 Supabase Storage 後，將 URL 儲存在 `user_profiles.avatar_url` 欄位中。

Storage URL 格式：
```
https://{project-ref}.supabase.co/storage/v1/object/public/user-avatars/{user_id}/avatar.jpg
```

## 注意事項

- **本地優先**：目前實作中，頭貼優先儲存在本地 SwiftData（`avatarData`）
- **雲端備份**：可以選擇性地將頭貼上傳到 Supabase Storage 作為備份
- **同步策略**：未來可以實作自動同步，將本地 `avatarData` 上傳到 Storage
