import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:livespeechtotext/livespeechtotext.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:dart_openai/dart_openai.dart';
import 'env/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OpenAI.apiKey = apiKey;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Set the OpenAI API key from the .env file.
  late Livespeechtotext _livespeechtotextPlugin;
  late String _recognisedText;
  late String _transcription;
  String? _localeDisplayName = '';
  StreamSubscription<dynamic>? onSuccessEvent;

  bool microphoneGranted = false;

  @override
  void initState() {
    super.initState();
    _livespeechtotextPlugin = Livespeechtotext();

    // _livespeechtotextPlugin.setLocale('ms-MY').then((value) async {
    //   _localeDisplayName = await _livespeechtotextPlugin.getLocaleDisplayName();

    //   setState(() {});
    // });

    _livespeechtotextPlugin.getLocaleDisplayName().then((value) => setState(
          () => _localeDisplayName = value,
        ));

    // onSuccessEvent = _livespeechtotextPlugin.addEventListener('success', (text) {
    //   setState(() {
    //     _recognisedText = text ?? '';
    //   });
    // });

    binding().whenComplete(() => null);

    // _livespeechtotextPlugin
    //     .getSupportedLocales()
    //     .then((value) => value?.entries.forEach((element) {
    //           print(element);
    //         }));

    _recognisedText = '';
    _transcription = '';
  }

  @override
  void dispose() {
    onSuccessEvent?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Live Speech To Text'),
            ),
            body: SingleChildScrollView(
                child: Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    children: [
                      Text(_recognisedText),
                      Text(_transcription),
                      if (!microphoneGranted)
                        ElevatedButton(
                          onPressed: () {
                            binding();
                          },
                          child: const Text("Check Permissions"),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                              onPressed: microphoneGranted
                                  ? () {
                                      print("transcribe button pressed");
                                      try {
                                        transcribe();
                                      } on PlatformException {
                                        print('error');
                                      }
                                    }
                                  : null,
                              child: Text("Press To Transcribe")),
                          ElevatedButton(
                              onPressed: microphoneGranted
                                  ? () {
                                      print("start button pressed");
                                      try {
                                        _livespeechtotextPlugin.start();
                                      } on PlatformException {
                                        print('error');
                                      }
                                    }
                                  : null,
                              child: const Text('Start')),
                          ElevatedButton(
                              onPressed: microphoneGranted
                                  ? () {
                                      print("stop button pressed");
                                      try {
                                        _livespeechtotextPlugin.stop();
                                      } on PlatformException {
                                        print('error');
                                      }
                                    }
                                  : null,
                              child: const Text('Stop')),
                        ],
                      ),
                      Text("Locale: $_localeDisplayName"),
                    ],
                  ),
                ),
              ],
            ))));
  }

  Future<OpenAIAudioModel> transcribe() async {
    return Future.wait([]).then((_) async {
      OpenAIAudioModel transcription =
          await OpenAI.instance.audio.createTranscription(
        file: File(
            "/Users/jordanhaggett/Documents/flutter-stt/flutter_stt/lib/env/MLKDreamSpeech.mp3"),
        model: "whisper-1",
        // prompt: """User1: 'Hello.',
        // User2: 'uhh Goodmorning, everyone.' """,
        responseFormat: OpenAIAudioResponseFormat.json,
      );
      setState(() {
        _transcription = transcription.text.toString();
      });
      return transcription;
    });
  }

  Future<dynamic> binding() async {
    onSuccessEvent?.cancel();

    return Future.wait([]).then((_) async {
      // Check if the user has already granted microphone permission.
      var permissionStatus = await Permission.microphone.status;

      // If the user has not granted permission, prompt them for it.
      if (!microphoneGranted) {
        await Permission.microphone.request();

        // Check if the user has already granted the permission.
        permissionStatus = await Permission.microphone.status;

        if (!permissionStatus.isGranted) {
          return Future.error('Microphone access denied');
        }
      }

      // Check if the user has already granted speech permission.
      if (Platform.isIOS) {
        var speechStatus = await Permission.speech.status;

        // If the user has not granted permission, prompt them for it.
        if (!microphoneGranted) {
          await Permission.speech.request();

          // Check if the user has already granted the permission.
          speechStatus = await Permission.speech.status;

          if (!speechStatus.isGranted) {
            return Future.error('Speech access denied');
          }
        }
      }

      return Future.value(true);
    }).then((value) {
      microphoneGranted = true;

      // listen to event "success"
      onSuccessEvent =
          _livespeechtotextPlugin.addEventListener("success", (value) {
        if (value.runtimeType != String) return;
        if ((value as String).isEmpty) return;

        setState(() {
          _recognisedText = value;
        });
      });

      setState(() {});
    }).onError((error, stackTrace) {
      // toast
      log(error.toString());
      // open app setting
    });
  }
}
