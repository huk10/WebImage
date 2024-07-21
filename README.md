# WebImage

WebImage 是一个强大的 SwiftUI 库，用于从网络下载和缓存图像。

## Features

* 轻松加载网络图片。
* 支持加载本地图片资源。
* 异步处理图片下载和缓存。
* 提供异步和同步两种使用方式。
* 支持内存和磁盘的多级缓存机制。
* 支持从缓存中获取图片数据。
* 在加载图片时显示自定义的占位符。
* 确保不会出现重复的网络请求。
* 附带了一个 BlurHash 实现。

## Usage

### 在 SwiftUI 中使用

```swift
let url = "http://192.168.50.4:8045/assets/photo/795d411eb801002.jpg"
#Preview {
    WebImage.url(URL(string: url)!)
        .cacheMemoryOnly()
        .forceRefresh()
        .onFailure { error in
            print("error: \(error)")
        }
        .onProgress { value in
            print("progress: \(value.fractionCompleted)")
        }
        .onSuccess { data in
            print("data.count: \(data.data.count)")
        }
        .resizable()
        .scaledToFit()
        .frame(width: 200, height: 200)
        .border(.red)
}
```

### 预加载和优先从缓存加载数据

```
Task {
    let url = URL(string: "http://192.168.50.4:8045/assets/photo/795d411eb801002.jpg")!
    let result = try! await ImageLoader.shared.url(.init(url: url))
    // result.data
}

```

### 使用 BlurHash

**使用 BlurHash 作为占位符** 
 
具体 BlurHash 的使用方法请查看：https://github.com/woltapp/blurhash/blob/master/Swift/BlurHashDecode.swift

```swift
#Preview {
    WebImage.url(imageURL)
        .onFailureImage(Constants.onFailureImage)
        .placeholder {
            if let uiImage = UIImage(blurHash: photo.blurHash, size: blurSize) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.systemGray
            }
        }
        .onSuccess { resp in
            self.uiImage = resp.uiImage
        }
        .resizable()
        .scaledToFill()
        .frame(width: width, height: height)
        .cornerRadius(10)
        .clipped()
}
```

**编码到 BlurHash**

注意需要使用缩略图或尽可能小的图片进行计算，否则可能会非常耗时（过大的图片可能会到分级别，50*50 的图片耗时大概在 25ms）。

具体使用方法请查看：https://github.com/woltapp/blurhash/blob/master/Swift/BlurHashEncode.swift

```
uiImage.blurHash(numberOfComponents: (4, 5))
```

## License

WebImage is released under the [MIT license](./LICENSE). See LICENSE for details.


