import 'package:f_glitch/f_glitch.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'f_glitch sample',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ImageProvider _imageProvider = const AssetImage('assets/sample.jpg');
  double _frequency = 1000;
  double _glitchRate = 50;

  void _changeSlider(double e) => setState(() {
        _frequency = e;
        controller.setFrequency(_frequency.toInt());
      });

  void _changeGlitchSlider(double e) => setState(() {
        _glitchRate = e;
        controller.setGlitchRate(_glitchRate.toInt());
      });

  GlitchController controller = GlitchController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SingleChildScrollView;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 500,
            child: FGlitch(
              imageProvider: _imageProvider,
              controller: controller,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Row(children: <Widget>[
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _imageProvider = const AssetImage('assets/sample.jpg');
                });
              },
              child: const Text('local image'),
            ),
            const SizedBox(
              width: 10,
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _imageProvider = const NetworkImage(
                      "https://source.unsplash.com/M6ule9BFwYg");
                });
              },
              child: const Text('network image'),
            ),
          ]),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  controller.play();
                },
                child: const Text('play'),
              ),
              const SizedBox(
                width: 10,
              ),
              ElevatedButton(
                onPressed: () {
                  controller.pause();
                },
                child: const Text('pause'),
              ),
              const SizedBox(
                width: 10,
              ),
              ElevatedButton(
                onPressed: () {
                  controller.glitch();
                },
                child: const Text('glitch'),
              ),
              const SizedBox(
                width: 10,
              ),
              ElevatedButton(
                onPressed: () {
                  controller.reset();
                },
                child: const Text('reset'),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Column(
            children: <Widget>[
              Text("glitch interval: ${_frequency.toInt()}"),
              Slider(
                label: '${_frequency.toInt()}',
                min: 100,
                max: 5000,
                value: _frequency,
                divisions: 100,
                onChanged: _changeSlider,
              )
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Column(
            children: <Widget>[
              Center(
                  child:
                      Text("effect occurrence rate: ${_glitchRate.toInt()}")),
              Slider(
                label: '${_glitchRate.toInt()}',
                min: 0,
                max: 100,
                value: _glitchRate,
                divisions: 100,
                onChanged: _changeGlitchSlider,
              )
            ],
          ),
        ]),
      ),
    );
  }
}
