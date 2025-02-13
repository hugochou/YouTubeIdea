# API 适配说明

## Silicon Flow API

### 音频转写服务
- 基础URL: https://api.siliconflow.cn/v1/audio/transcriptions
- 请求方式: POST
- 文件限制: 20MB
- 支持格式: mp3, m4a, wav
- 认证方式: Bearer Token

#### 请求参数
- file: 音频文件 (multipart/form-data)
- model: FunAudioLLM/SenseVoiceSmall

#### 错误处理
- 413: 文件过大，需分割
- 429: 请求过频，需延迟重试
- 500: 服务器错误，可重试

## DeepSeek API

### 翻译服务
- 基础URL: https://api.deepseek.com/v1/chat/completions
- 请求方式: POST
- 认证方式: Bearer Token
- 模型: deepseek-chat
- 最大tokens: 8192

### 润色服务
- 使用相同endpoint
- 不同prompt模板
- 支持中英文

## 错误处理策略

### 通用错误
1. 网络错误: 自动重试3次
2. 认证错误: 提示用户检查API密钥
3. 服务限流: 指数退避重试

### 特定错误
1. 文件大小超限: 自动分割处理
2. 格式不支持: 自动转换格式
3. 内容超长: 分段处理

## 性能优化

### 并发处理
1. 大文件分片并行处理
2. 响应流式处理
3. 异步操作队列

### 缓存策略
1. 临时文件管理
2. 处理结果缓存
3. API响应缓存

## 安全建议

### API密钥管理
1. 密钥加密存储
2. 运行时解密
3. 定期轮换

### 数据安全
1. 临时文件加密
2. 处理完成自动清理
3. 敏感信息脱敏

## 开发建议

### 代码组织
1. 服务封装
2. 错误统一处理
3. 状态管理规范

### 测试策略
1. 单元测试覆盖
2. 集成测试
3. 错误场景模拟 