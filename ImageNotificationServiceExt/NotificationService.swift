import UserNotifications
import FirebaseMessaging

//class NotificationService: UNNotificationServiceExtension {
//    var contentHandler: ((UNNotificationContent) -> Void)?
//    var bestAttemptContent: UNMutableNotificationContent?
//
//    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
//        self.contentHandler = contentHandler
//        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
//        
//        if let bestAttemptContent = bestAttemptContent {
//            // Проверяем, есть ли URL изображения в data
//            if let imageURLString = bestAttemptContent.userInfo["image"] as? String,
//               let imageURL = URL(string: imageURLString) {
//                // Скачиваем изображение
//                downloadImage(from: imageURL) { [weak self] downloadedImage in
//                    if let downloadedImage = downloadedImage {
//                        do {
//                            let attachment = try UNNotificationAttachment(identifier: "image", url: downloadedImage, options: nil)
//                            bestAttemptContent.attachments = [attachment]
//                        } catch {
//                            contentHandler(bestAttemptContent)
//                            return
//                        }
//                    }
//                    // Вызываем contentHandler с модифицированным контентом
//                    contentHandler(bestAttemptContent)
//                }
//            } else {
//                // Если изображения нет, показываем уведомление как есть
//                contentHandler(bestAttemptContent)
//            }
//        }
//    }
//    
//    override func serviceExtensionTimeWillExpire() {
//        // Если время истекает (30 сек лимит), показываем уведомление без изображения
//        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
//            contentHandler(bestAttemptContent)
//        }
//    }
//    
//    private func downloadImage(from url: URL, completion: @escaping (URL?) -> Void) {
//        let task = URLSession.shared.dataTask(with: url) { data, response, error in
//            guard let data = data, error == nil, let mimeType = response?.mimeType, mimeType.hasPrefix("image/") else {
//                print("Ошибка скачивания изображения: \(error?.localizedDescription ?? "Неизвестная ошибка")")
//                completion(nil)
//                return
//            }
//            
//            // Сохраняем изображение во временный файл
//            let tempDirectory = NSTemporaryDirectory()
//            let fileName = UUID().uuidString + ".jpg" // Или .png, в зависимости от типа
//            let fileURL = URL(fileURLWithPath: tempDirectory + fileName)
//            
//            do {
//                try data.write(to: fileURL)
//                completion(fileURL)
//            } catch {
//                print("Ошибка сохранения изображения: \(error)")
//                completion(nil)
//            }
//        }
//        task.resume()
//    }
//}

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
           // bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
Messaging.serviceExtension().populateNotificationContent(bestAttemptContent, withContentHandler: contentHandler)

        }
    }
}
