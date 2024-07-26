import 'package:get/get.dart';
import 'package:mqtt/model/message_model.dart';

class HomeController extends GetxController{
  bool isOnline = false;

  List<MessageModel> messages = [
    const MessageModel(
      message: 'Hello',
      time: '10:00',
      senderId: '1',
    ),
    const MessageModel(
      message: 'Hi',
      time: '10:01',
      senderId: '2',
    ),
    const MessageModel(
      message: 'How are you?',
      time: '10:02',
      senderId: '1',
    ),
    const MessageModel(
      message: 'I am fine',
      time: '10:03',
      senderId: '2',
    ),
  ];
}