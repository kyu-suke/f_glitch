# notice
[animated_glitch](https://pub.dev/packages/animated_glitch) is more powerful package.
It is better to use above package to add glitch effect images.

# f_glitch

[![pub package](https://img.shields.io/pub/v/f_glitch.svg)](https://pub.dev/packages/f_glitch)

[web demo](https://kyu-suke.github.io/examples/flttr/)

Glitch effects to images.

- basic

![basic_](https://user-images.githubusercontent.com/9162117/183775728-77000c77-73aa-4395-9b58-0abff74751ea.gif)

- highFrequency

![highFrequency_](https://user-images.githubusercontent.com/9162117/183775762-64edf697-2c27-4431-8208-935b631b99de.gif)


### mov file demo
https://user-images.githubusercontent.com/9162117/183772705-6db4aec8-993b-45e4-93e1-35e95a1a3543.mov

https://user-images.githubusercontent.com/9162117/183772721-f78558e6-82f7-4a64-8626-32b3b6117245.mov

## How to use

In your pubspec.yaml:
```yaml
dependencies:
  f_glitch: ^0.1.1
```

```dart
FGlitch(
  imageProvider: const AssetImage('assets/sample.jpg')
);
```
