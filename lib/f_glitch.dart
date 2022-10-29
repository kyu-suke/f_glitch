import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that renders an glitched image.
class FGlitch extends StatefulWidget {
  const FGlitch(
      {super.key, required this.imageProvider, this.imageFit, this.controller});

  /// A image that is used to effected.
  final ImageProvider imageProvider;

  /// How to fit the image during layout.
  final BoxFit? imageFit;

  /// A controller about glitch actions.
  final GlitchController? controller;

  @override
  State<FGlitch> createState() => _FGlitchState();
}

class _FGlitchState extends State<FGlitch> {
  final _key = GlobalKey();

  bool get _showColorShift => widget.controller!._showColorShift;

  bool get _showGlitch => widget.controller!._showGlitch;

  bool get _showScanline => widget.controller!._showScanline;

  List<_ColorChannel> get _colorChannels => widget.controller!._colorChannels;

  List<_GlitchMask> get _glitchChannels => widget.controller!._glitchChannels;

  List<Color> get _scanLine => widget.controller!._scanLine;

  List<double> get _scanStops => widget.controller!._scanStops;

  double get _scanLineDegree => widget.controller!._scanLineDegree;

  void rebuild() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.controller?.setKey(_key);
      widget.controller?.addListener(rebuild);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _channelWidget(_ColorChannel cc) {
    return Positioned.fill(
      left: cc.leftPosition,
      top: cc.topPosition,
      child: _BlendMask(
        blendMode: BlendMode.plus,
        child: Image(
          image: widget.imageProvider,
          fit: widget.imageFit,
          color: cc._color,
          colorBlendMode: BlendMode.multiply,
        ),
      ),
    );
  }

  Widget _glitchWidget(_GlitchMask g) {
    return Center(
      child: Container(
        margin: g._leftMargin,
        child: Stack(children: [
          ClipPath(
            clipper: _InvertedCircleClipper(g._topPosition, g._heightRate),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: Wrap(
              children: [
                Image(
                  image: widget.imageProvider,
                  fit: widget.imageFit,
                  color: Colors.white,
                  colorBlendMode: g._blendMode,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // fixme: This widget does not appear to work very well. If there is a better way, I would like to switch.
  Widget _scanLineWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            transform: GradientRotation(_scanLineDegree),
            tileMode: TileMode.repeated,
            begin: FractionalOffset.topCenter,
            end: FractionalOffset.bottomCenter,
            colors: _scanLine,
            stops: _scanStops),
      ),
      child: Image(
        image: widget.imageProvider,
        color: const Color.fromRGBO(1, 1, 1, 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _key,
      child: NotificationListener(
          child: Stack(
        children: [
          Image(
            image: widget.imageProvider,
            color: _showColorShift ? Colors.black : null,
          ),

          // RGB shift
          if (_showColorShift) ..._colorChannels.map((e) => _channelWidget(e)),

          // glitch
          if (_showGlitch)
            ..._glitchChannels
                .where((element) => element._show)
                .map((g) => _glitchWidget(g)),

          // scanline
          if (_showScanline) _scanLineWidget(),
        ],
      )),
    );
  }
}

class _InvertedCircleClipper extends CustomClipper<Path> {
  const _InvertedCircleClipper(this._top, this._heightRate);

  final double _top;
  final double _heightRate;

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(
        Rect.fromLTWH(0, _top, size.width, size.height / _heightRate),
      )
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ColorChannel {
  const _ColorChannel(this._color,
      {this.topPosition = 0, this.leftPosition = 0});

  final Color _color;

  /// [_ColorChannel]'s top position.
  final double topPosition;

  /// [_ColorChannel]'s left position.
  final double leftPosition;
}

class _GlitchMask {
  _GlitchMask(this._blendMode);

  final BlendMode _blendMode;
  EdgeInsets? _leftMargin;
  double _topPosition = 0;
  double _heightRate = 1;
  bool _show = false;

  void _setPosition(EdgeInsets margin, double topPosition, double heightRate) {
    _leftMargin = margin;
    _topPosition = topPosition;
    _heightRate = heightRate;
  }

  void _setShow(bool show) {
    _show = show;
  }
}

class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({
    required this.blendMode,
    Key? key,
    Widget? child,
  }) : super(key: key, child: child);

  /// A widget that renders an glitched image.
  final BlendMode blendMode;

  final double _opacity = 1.0;

  @override
  RenderObject createRenderObject(context) {
    return _RenderBlendMask(blendMode, _opacity);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
    renderObject.opacity = _opacity;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this.blendMode, this.opacity);

  /// ColorChannels blend mode.
  BlendMode blendMode;

  /// ColorChannels opacity.
  double opacity;

  @override
  void paint(context, offset) {
    context.canvas.saveLayer(
        offset & size,
        Paint()
          ..blendMode = blendMode
          ..color = Color.fromARGB((opacity * 255).round(), 255, 255, 255));

    super.paint(context, offset);

    context.canvas.restore();
  }
}

/// A controller to notify glitch data to FGlitch.
/// Effect has a [glitchRate]% chance of occurring every [frequency] milliseconds.
class GlitchController extends ChangeNotifier {
  GlitchController(
      {this.frequency = 1000,
      this.glitchRate = 50,
      autoplay = true,
      showColorShift = true,
      showGlitch = true,
      showScanline = false,
        double glitchLevel = 1,
      List<Color> channelColors = const [],
      List<BlendMode> glitchMasks = const [],
      ScanLineGradient? scanLineGradient}) {
    _colorChannels =
        _defaultChannelColors.map((c) => _ColorChannel(c)).toList();
    _glitchChannels = _defaultGlitchList.map((c) => _GlitchMask(c)).toList();
    _frequency = frequency;
    _showColorShift = showColorShift;
    _showGlitch = showGlitch;
    _showScanline = showScanline;
    _scanLineGradient = scanLineGradient ?? ScanLineGradient();
    _glitchLevel = glitchLevel;

    if (autoplay) {
      play();
    }
  }

  /// Interval that happens effect. milliseconds.
  int frequency;

  /// Rate that happens effect. [1 - 100]
  int glitchRate;

  late double _glitchLevel;

  late bool _showColorShift;

  late bool _showGlitch;

  late bool _showScanline;

  late ScanLineGradient _scanLineGradient;

  late List<_ColorChannel> _colorChannels = [];

  late List<_GlitchMask> _glitchChannels = [];

  List<Timer> _timers = [];

  bool _isPlay = false;

  int _frequency = 0;

  GlobalKey? _key;

  double get _widgetHeight => _key?.currentContext!.size!.height ?? 0;

  List<Color> get _scanLine => _scanLineGradient._scanLine;

  List<double> get _scanStops => _scanLineGradient._scanStops;

  double get _scanLineDegree => _scanLineGradient._scanLineDegree;

  double get _glitchCoefficient => 1.1*_glitchLevel;

  final List<Color> _defaultChannelColors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  final List<BlendMode> _defaultGlitchList = const [
    BlendMode.softLight,
    BlendMode.multiply,
  ];

  static final Random _random = Random();

  @override
  void dispose() {
    _resetTimer();
    super.dispose();
  }

  void _resetTimer() {
    for (var timer in _timers) {
      timer.cancel();
    }
    _timers = [];
  }

  /// Set glitch level.
  void setGlitchLevel(double level) {
    _glitchLevel = level;
    notifyListeners();
  }

  /// Show color shift effect.
  void showColorShift() {
    _showColorShift = true;
    notifyListeners();
  }

  /// Hide color shift effect.
  void hideColorShift() {
    _showColorShift = false;
    notifyListeners();
  }

  /// Show glitch effect
  void showGlitch() {
    _showGlitch = true;
    notifyListeners();
  }

  /// Hide glitch effect
  void hideGlitch() {
    _showGlitch = false;
    notifyListeners();
  }

  /// Show scan line.
  void showScanline() {
    _showScanline = true;
    notifyListeners();
  }

  /// Hide scan line.
  void hideScanline() {
    _showScanline = false;
    notifyListeners();
  }

  /// Play glitch animation interval.
  void play() {
    if (_isPlay) return;
    _startGlitchInterval();
    _isPlay = true;
  }

  /// Pause glitch animation interval.
  void pause() {
    _resetTimer();
    _isPlay = false;
  }

  /// Appear glitch effect.
  void glitch() {
    _colorChannels = _colorChannels
        .map((e) => _ColorChannel(e._color,
            topPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient),
            leftPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient)))
        .toList();

    for (final g in _glitchChannels) {
      g._setPosition(_randomSideMargin(-50 * _glitchCoefficient, 50 * _glitchCoefficient),
          _randomPosition(0, _widgetHeight * _glitchCoefficient), _randomPosition(5 * _glitchCoefficient, 30 * _glitchCoefficient));
      g._setShow(true);
    }
    notifyListeners();
  }

  /// Disappear glitch effect.
  void reset() {
    _colorChannels =
        _colorChannels.map((e) => _ColorChannel(e._color)).toList();

    for (final g in _glitchChannels) {
      g._setShow(false);
    }
    notifyListeners();
  }

  /// Set FGlitch GlobalKey to use getting widget height and getting ui.Image.
  void setKey(GlobalKey key) {
    _key = key;
  }

  /// Height at which the glitch effect appears. Usually, the height is the widget height.
  void setFrequency(int i) {
    frequency = i;
  }

  /// Height at which the glitch effect appears. Usually, the height is the widget height.
  void setGlitchRate(int i) {
    glitchRate = i;
  }

  /// Getting glitched image as ui.Image
  /// When you render as flutter web, you need to add some options as below.
  /// --web-render canvaskit, --release, --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false
  /// e.g.) flutter run -d chrome --web-renderer canvaskit --release --dart-define=BROWSER_IMAGE_DECODING_ENABLED=false
  Future<ui.Image> asImage() async {
    final boundary =
        _key!.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return await boundary.toImage();
  }

  double _randomPosition(double min, double max) {
    return _random.nextDouble() * (max - min) + min;
  }

  EdgeInsets _randomSideMargin(double min, double max) {
    var side = _random.nextDouble() * (max - min) + min;
    return side < 0
        ? EdgeInsets.only(right: side * -1)
        : EdgeInsets.only(left: side);
  }

  void _startGlitchInterval() {
    final timer =
        Timer.periodic(Duration(milliseconds: frequency), (Timer timer) {
      if (_random.nextInt(100) > glitchRate) return;

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient),
                  leftPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient)))
              .toList()),
          100);

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) => _ColorChannel(cc._color,
                  topPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient),
                  leftPosition: _randomPosition(-10 * _glitchCoefficient, 10 * _glitchCoefficient)))
              .toList()),
          200);

      _setTimer(
          _onTimerColorChannelShift(_colorChannels
              .map((cc) =>
                  _ColorChannel(cc._color, topPosition: 0, leftPosition: 0))
              .toList()),
          300);

      var milliseconds = 100;
      _glitchChannels.asMap().forEach((key, value) {
        _setTimer(_onTimerGlitch(key), milliseconds);
        milliseconds += 100;
      });

      if (_frequency != frequency) {
        timer.cancel();
        _startGlitchInterval();
      }
    });
    _timers.add(timer);
  }

  void _setTimer(void Function(Timer) fn, int milliseconds) {
    final timer = Timer.periodic(
      Duration(milliseconds: milliseconds),
      fn,
    );
    _timers.add(timer);
  }

  void Function(Timer) _onTimerColorChannelShift(
      List<_ColorChannel> colorChannels) {
    return (Timer timer) {
      timer.cancel();

      colorChannels.asMap().forEach((index, cc) {
        colorChannels[index] = cc;
      });
      _colorChannels = colorChannels;
      notifyListeners();
    };
  }

  void Function(Timer) _onTimerGlitch(int key) {
    return (Timer timer) {
      timer.cancel();

      var glitchMask = _glitchChannels[key];
      glitchMask._setPosition(_randomSideMargin(-50 * _glitchCoefficient, 50 * _glitchCoefficient),
          _randomPosition(0, _widgetHeight * _glitchCoefficient), _randomPosition(5 * _glitchCoefficient, 30 * _glitchCoefficient));
      glitchMask._setShow(true);
      _glitchChannels[key] = glitchMask;
      notifyListeners();

      final glitchTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (Timer timer) {
          timer.cancel();

          var glitchMask = _glitchChannels[key];
          glitchMask._setShow(false);
          _glitchChannels[key] = glitchMask;
          notifyListeners();
        },
      );
      _timers.add(glitchTimer);
    };
  }
}

/// Configure about scan lines.
class ScanLineGradient {
  ScanLineGradient({
    int count = 400,
    double degree = 180,
  }) {
    _count = count;
    _degree = degree;
  }

  late int _count;

  late double _degree;

  int get _lineSet => _count * 4;

  double get _scanLineDegree => (_degree * -1) * pi / 180;

  List<Color> get _scanLine {
    List<Color> colors = [];
    var flip = false;
    for (var i = 0; i < _lineSet; i++) {
      if (i % 2 == 0) {
        flip = !flip;
      }
      final col = flip
          ? const Color.fromRGBO(0, 0, 0, 1)
          : const Color.fromRGBO(0, 0, 0, 0.0);
      colors.add(col);
    }
    return colors;
  }

  List<double> get _scanStops {
    List<double> base = [
      ...List.generate(_lineSet, (index) {
        return index % 2 == 0
            ? ((index * (1 / _lineSet)))
            : (((index - 1) * (1 / _lineSet)));
      })
    ];

    List<double> stops = List.filled(_lineSet, 0);
    stops.asMap().forEach((key, value) {
      if (key == 0) {
        stops[key] = 0;
      } else if (key == stops.length - 1) {
        stops[key] = 1;
      } else {
        stops[key] = base[key + 1];
      }
    });
    return stops;
  }
}
