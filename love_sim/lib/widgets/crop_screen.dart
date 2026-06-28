import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:love_sim/theme/app_theme.dart';
import 'package:love_sim/theme/app_theme_provider.dart';

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;
  const CropScreen({super.key, required this.imageBytes, this.aspectRatio = 1.0});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _image;
  Size? _imageSize;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    _image = frame.image;
    _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
    if (mounted) setState(() => _loading = false);
  }

  Future<Uint8List?> _doCrop(Size cropSize) async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppThemeProvider>().config;
    final size = MediaQuery.of(context).size;
    final cropW = size.width - 40;
    final cropH = cropW / widget.aspectRatio;
    final cropSize = Size(cropW, cropH);

    if (cropH > size.height - 180) {
      final adjustedH = size.height - 180;
      final adjustedW = adjustedH * widget.aspectRatio;
      final adjustedSize = Size(adjustedW, adjustedH);
      return _buildContent(size, adjustedSize, t);
    }
    return _buildContent(size, cropSize, t);
  }

  Widget _buildContent(Size screenSize, Size cropSize, AppThemeConfig t) {
    return Container(
      color: CupertinoColors.black,
      child: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Text('取消', style: TextStyle(color: t.textSecondary, fontSize: 16)),
              ),
              const Spacer(),
              Text('裁剪图片', style: TextStyle(color: t.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              CupertinoButton(
                onPressed: () async {
                  final result = await _doCrop(cropSize);
                  if (result != null && mounted) Navigator.pop(context, result);
                },
                padding: EdgeInsets.zero,
                minSize: 0,
                child: Text('完成', style: TextStyle(color: t.accent, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(radius: 20))
                : Center(
                    child: SizedBox(
                      width: cropSize.width,
                      height: cropSize.height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(children: [
                          InteractiveViewer(
                            transformationController: _transformCtrl,
                            minScale: 0.3,
                            maxScale: 3.0,
                            constrained: false,
                            child: SizedBox(
                              width: cropSize.width,
                              height: cropSize.height,
                              child: RepaintBoundary(
                                key: _repaintKey,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _imageSize?.width ?? cropSize.width,
                                    height: _imageSize?.height ?? cropSize.height,
                                    child: RawImage(image: _image, fit: BoxFit.fill),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: CupertinoColors.white.withAlpha(140), width: 2),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: t.bgWarm,
            ),
            child: Text('拖动/缩放图片，使主体在框内', style: TextStyle(color: t.textMuted, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}
