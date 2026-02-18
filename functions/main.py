import firebase_functions
from firebase_functions import firestore_fn
from firebase_admin import initialize_app, firestore, messaging

initialize_app()

@firestore_fn.on_document_created(document="chats/{chatId}/messages/{msgId}")
def send_chat_notification(event: firestore_fn.Event) -> None:
    msg_data = event.data.to_dict()
    chat_id = event.params["chatId"]

    sender_id = msg_data.get("senderId")
    sender_name = msg_data.get("senderName", "Someone")
    text = msg_data.get("text", "")

    if not sender_id or not text:
        return

    parts = chat_id.split("_")
    if len(parts) < 2:
        return
    uid1, uid2 = parts[0], parts[1]
    recipient_id = uid2 if sender_id == uid1 else uid1

    user_doc = firestore.client().document(f"users/{recipient_id}").get()
    if not user_doc.exists:
        return
    token = user_doc.to_dict().get("fcmToken")
    if not token:
        return

    message = messaging.Message(
        notification=messaging.Notification(
            title=sender_name,
            body=text[:100] + ("..." if len(text) > 100 else "")
        ),
        data={
            "chatId": chat_id,
            "senderName": sender_name
        },
        token=token,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="chatsapp_messages",
                sound="default",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True)
            )
        ),
    )

    try:
        response = messaging.send(message)
        print("Sent notification:", response)
    except Exception as e:
        print("Error sending notification:", e)
