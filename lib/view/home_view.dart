import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt/controller/home_controller.dart';
import 'package:mqtt/model/message_model.dart';
import 'package:mqtt/utils/message_bubble.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
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

  RxString mqttData = ''.obs;

  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? clientUpdate;
  RxBool isConnected = false.obs;


  late MqttServerClient client;

  @override
  void initState() {

    print("IN inti-------------------");
    mqttConnect(
      brokerUrl: "ec2-3-110-172-173.ap-south-1.compute.amazonaws.com",
      port: 1883,
      username: "brainstem",
      password: "RBSXwdK%eBMN&#o6",
    );

    super.initState();
  }

  @override
  dispose() {
    clientUpdate?.cancel();
    super.dispose();
  }

  void errorHandling({
    required Object error,
    required StackTrace stacktrace,
    bool displayError = false,
  }) {
    print("title: 'ERROR', content: $error");
    print("title: 'STACKTRACE', content: $stacktrace");

    if (displayError) {
      print('$error');
    }
  }


  Future<MqttServerClient> mqttConnect({
    required String brokerUrl,
    required int port,
    required String username,
    required String password,
  }) async {
    print("IN mqtt==================");
    try {

      print("IN try==================");
      client = MqttServerClient.withPort(
        brokerUrl,
        '',
        port,
      );
      client
        ..logging(on: false)
        ..keepAlivePeriod = 15
        ..autoReconnect = true
        ..onConnected = onConnected
        ..onDisconnected = onDisconnected
        ..onAutoReconnect = onAutoReconnected
        ..pongCallback = pong
        ..onSubscribed = onSubscribed
        ..onSubscribeFail = onSubscribeFail
        ..onUnsubscribed = onUnsubscribed
        ..connectionMessage = MqttConnectMessage();

      print("title: 'MQTT', content: 'CONNECTING'");

      try {
        await client.connect(username, password);
        print("MQTT:::::: CONNECTED'");
      } catch(e, stacktrace){
        print("MQTT:::::: CONNECTION FAILED'");
        print('ERROR: $e $stacktrace' );
      }

      if (checkIfConnected()) {
        print("title: 'MQTT', content: 'CONNECTED'");
      } else {
        print(
          "title: 'MQTT',"
          "content:"
          'CONNECTION FAILED - disconnecting, status is ${client.connectionStatus}',
        );
        client.disconnect();
      }

      await clientUpdate?.cancel();

      clientUpdate = client.updates?.listen((c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final payload =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        handleClientUpdate(topic: c[0].topic, payload: payload);
      });
    } catch (error, stacktrace) {
      print("IN connect catch==================");
      errorHandling(error: error, stacktrace: stacktrace);
      client.disconnect();
    }
    return client;
  }


  void onConnected() {
    isConnected(true);
    print('MQTT_LOGS:: Connected');
  }


  void onDisconnected() {
    isConnected(false);
    print("title: 'MQTT', content: 'Disconnected'");
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print(
        "title: 'MQTT',"
        "content: 'OnDisconnected callback is solicited, this is correct'",
      );
    } else {
      print(
        "title: 'MQTT',"
        "content:"
        'OnDisconnected callback is unsolicited or none, this is incorrect - exiting',
      );
    }
  }


  void onAutoReconnected() {
    print("title: 'MQTT', content: 'AutoReconnected'");
    if (checkIfConnected()) {
      isConnected(true);
    } else {
      isConnected(false);
    }
  }


  void pong() {
    print("title: 'MQTT', content: 'Ping response client callback invoked'");
  }

  void onSubscribed( String topic) {
      // MqttSubscription topic
      // ) {
    print("title: 'MQTT', content: 'Subscribed topic --> $topic'");
  }


  void onSubscribeFail(String topic) {
      // MqttSubscription topic) {
    print("title: 'MQTT', content: 'SubscribeFail topic --> $topic'");
  }


  void onUnsubscribed(String? topic) {
      // MqttSubscription topic) {
    print(
      "'MQTT LOG': 'Subscription unsubscribed for topic $topic',"
    );
  }


  bool checkIfConnected() {
    print(
      "title: 'client.connectionStatus?.state'"
      "content: client.connectionStatus?.state",
    );
    return client.connectionStatus?.state == MqttConnectionState.connected;
  }


  void mqttSubscribeTopic({required String topic}) {
    try {
      client.subscribe(topic, MqttQos.exactlyOnce);
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }


  void mqttUnSubscribeTopic({required String topic}) {
    try {
      // client.unsubscribeStringTopic(topic);
      client.unsubscribe(topic);
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }


  void publishToTopic({required String topic, required String message}) {
    try {
      if (isConnected()) {
        // printLog(
        //   title: 'MQTT_PUBLISH',
        //   content: 'TOPIC : $topic, PAYLOAD : $message',
        // );

        final builder = MqttClientPayloadBuilder()..addString(message);
        //MqttPayloadBuilder()..addString(message);
        client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      }
    } catch (error, stacktrace) {
      errorHandling(error: error, stacktrace: stacktrace);
    }
  }


  void handleClientUpdate({required String? topic, required String payload}) {
    print(
      "title: 'MQTT',"
      "content: 'TOPIC : $topic, PAYLOAD : $payload',"
    );

    // final res = jsonDecode(payload);
    // final protocol = stringToEnumMqttProtocol(res['protocol']);
    //
    // switch (protocol) {
    //   case EnumMqttProtocol.userOnline:
    //     protocolUserOnline(
    //       topic: topic,
    //       isOnline: res['data'],
    //     );
    //     break;
    //
    //   case EnumMqttProtocol.checkHeadband:
    //     protocolCheckHeadband(payload: payload);
    //     break;
    //
    //   case EnumMqttProtocol.checkImpedance:
    //     protocolCheckImpedance(topic: topic, payload: res);
    //     break;
    //
    //   case EnumMqttProtocol.patientSession:
    //     protocolSessionData(topic: topic, payload: payload);
    //     break;
    //
    //   case EnumMqttProtocol.error:
    //     protocolErrorData(topic: topic, payload: payload);
    //     break;
    //
    //   case EnumMqttProtocol.terminateSession:
    //     protocolTerminateSession(topic: topic);
    //     break;
    //   case EnumMqttProtocol.skipAssessment:
    //     protocolSkipAssessment(topic: topic, payload: payload);
    //     break;
    //   case EnumMqttProtocol.startSession:
    //   case EnumMqttProtocol.stopCheckImpedance:
    //   case EnumMqttProtocol.scanHeadband:
    //   case EnumMqttProtocol.completeSession:
    //   case EnumMqttProtocol.resumeSession:
    //   case EnumMqttProtocol.pauseSession:
    //   case EnumMqttProtocol.refreshPatientHome:
    //   // do nothing
    //     break;
    // }
  }


  // Future<void> subscribeToAllPatient() async {
  //   for (final item in patientController.listPatientData()) {
  //     mqttSubscribeTopic(
  //       topic:
  //       '${doctorController.doctorModel().data?.id}/${item.patientId}/Rx',
  //     );
  //
  //     await Future.delayed(const Duration(milliseconds: 10));
  //   }
  //
  //   await checkIfPatientConnectionStatus();
  // }
  //
  // Future<void> checkIfPatientConnectionStatus() async {
  //   for (final item in patientController.listPatientData()) {
  //     final sendData = {
  //       'protocol': EnumMqttProtocol.userOnline.name,
  //       'commandID': getUUID(),
  //     };
  //
  //     publishToTopic(
  //       topic:
  //       '${doctorController.doctorModel().data?.id}/${item.patientId}/Tx',
  //       message: jsonEncode(sendData),
  //     );
  //
  //     await Future.delayed(const Duration(milliseconds: 10));
  //   }
  // }
  //
  // void checkIfHeadbandIsConnected({required String patientID}) {
  //   final sendData = {
  //     'protocol': EnumMqttProtocol.checkHeadband.name,
  //     'commandID': getUUID(),
  //   };
  //
  //   publishToTopic(
  //     topic: '${doctorController.doctorModel().data?.id}/$patientID/Tx',
  //     message: jsonEncode(sendData),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellowAccent.shade100,
        title: Row(
          children: [
            Text(
              '● ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    !isOnline ? Colors.orangeAccent : Colors.lightGreenAccent,
              ),
            ),
            const SizedBox(width: 30),
            const Text('Messenger'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return MessageBubble(
                      message: messages[index].message,
                      isMe: messages[index].senderId == '1',
                      time: messages[index].time,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 30),
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  suffixIcon: IconButton(
                    onPressed: (){},
                    icon: const Icon(Icons.send,color:  Colors.grey,),
                ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
              )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
