import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:misfortune_app/bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  usePathUrlStrategy();
  final queryParams = Uri.base.queryParameters;
  runApp(MyApp(code: queryParams['code'], wheelId: queryParams['wheelID']));
}

class MyApp extends StatelessWidget {
  final String? code;
  final String? wheelId;

  const MyApp({super.key, required this.code, required this.wheelId});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheel of Misfortune',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: BlocPage(code: code, wheelId: wheelId),
    );
  }
}

class BlocPage extends StatelessWidget {
  final String? code;
  final String? wheelId;

  const BlocPage({super.key, required this.code, required this.wheelId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MisfortuneBloc>(
      create:
          (context) => MisfortuneBloc(
            client: HttpMisfortuneClient(),
            code: code,
            wheelId: wheelId,
          ),
      child: const MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 48),
            child: SpinContent(),
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 20,
        child: Center(
          child: BlocBuilder<MisfortuneBloc, MisfortuneState>(
            builder: (context, state) {
              final movement = state.movement;
              if (movement == null) {
                return const Offstage();
              } else {
                return Text(movement);
              }
            },
          ),
        ),
      ),
    );
  }
}

class SpinContent extends StatelessWidget {
  const SpinContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MisfortuneBloc, MisfortuneState>(
      builder: (context, state) {
        final bloc = BlocProvider.of<MisfortuneBloc>(context);
        switch (state.stage) {
          case Stage.wrongBrowser:
            return const Text(
              'Leider funktioniert diese Webseite nicht in deinem Browser',
            );
          case Stage.awaitingPermissions:
            return Column(
              children: [
                const Text(
                  'Bitte gib der Webseite Zugriff auf den Beschleunigungssensor',
                ),
                ElevatedButton(
                  onPressed: bloc.requestSafariPermissions,
                  child: const Text('OK'),
                ),
              ],
            );
          case Stage.awaitingPress:
            return ElevatedButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.all(25)),
              ),
              onPressed: () => bloc.add(const PressButtonEvent()),
              child: Text(
                'Ich habe Durst',
                style: DefaultTextStyle.of(context).style,
              ),
            );
          case Stage.scanningCode:
            return const QrScanner();
          case Stage.awaitingSpin:
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dreh das Rad!'),
                if (state.tooSlow) const Text('Schneller!'),
              ],
            );
          case Stage.failed:
            return Text('Konnte das Rad nicht drehen 😢 (${state.error})');
          case Stage.spinning:
            return const Text('Prost!');
        }
      },
    );
  }
}

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(facing: CameraFacing.back);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Uri? _extractUri(Barcode barcode) {
    final String url;
    if (barcode.type == BarcodeType.url) {
      final rawUrl = barcode.url?.url;
      if (rawUrl == null) {
        return null;
      }
      url = rawUrl;
    } else if (barcode.type == BarcodeType.text) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) {
        return null;
      }
      url = rawValue;
    } else {
      return null;
    }

    return Uri.tryParse(url);
  }

  ScanQrEvent? _extractScanEvent(Barcode barcode) {
    final uri = _extractUri(barcode);
    if (uri != null && uri.authority == 'bembel.party') {
      final code = uri.queryParameters['code'];
      final wheelId = uri.queryParameters['wheelID'];
      if (code != null && wheelId != null) {
        return ScanQrEvent(code: code, wheelId: wheelId);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<MisfortuneBloc>(context);
    return MobileScanner(
      onDetect: (barcodeCapture) {
        for (final barcode in barcodeCapture.barcodes) {
          final event = _extractScanEvent(barcode);
          if (event != null) {
            bloc.add(event);
            break;
          }
        }
      },
      errorBuilder: (context, error, widget) {
        return Center(
          child: Text(
            'Error ${error.errorCode}: ${error.errorDetails?.message}',
          ),
        );
      },
      controller: _controller,
    );
  }
}
