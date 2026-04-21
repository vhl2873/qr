import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium QR Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      home: const QRWorkspaceScreen(),
    );
  }
}

class QRWorkspaceScreen extends StatefulWidget {
  const QRWorkspaceScreen({super.key});

  @override
  State<QRWorkspaceScreen> createState() => _QRWorkspaceScreenState();
}

class _QRWorkspaceScreenState extends State<QRWorkspaceScreen> {
  static const double _canvasAspectRatio = 4 / 5;
  static const double _defaultQrCardSize = 136;
  static const double _minQrCardSize = 88;
  static const double _maxQrCardSize = 220;

  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _captureKey = GlobalKey();

  int _selectedIndex = 0;
  String _qrData = '';
  bool _isSaving = false;
  File? _coverImageFile;
  Offset _qrOffset = Offset.zero;
  Size _canvasSize = Size.zero;
  double _qrCardSize = _defaultQrCardSize;
  bool _hasCustomQrPosition = false;
  double _scaleStartQrSize = _defaultQrCardSize;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedImage == null) {
        return;
      }

      setState(() {
        _coverImageFile = File(pickedImage.path);
        _hasCustomQrPosition = false;
        if (_canvasSize != Size.zero) {
          _qrOffset = _centerOffsetFor(_canvasSize);
        }
      });
    } catch (error) {
      _showSnackBar('Khong the mo thu vien anh: $error');
    }
  }

  Future<void> _saveArtwork() async {
    if (_qrData.trim().isEmpty) {
      _showSnackBar('Vui long nhap link truoc khi luu.');
      return;
    }

    final RenderRepaintBoundary? boundary = _captureKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      _showSnackBar('Khong tim thay khung anh de luu.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bool granted = await _requestGalleryPermission();
      if (!granted) {
        _showSnackBar('Chua duoc cap quyen truy cap thu vien anh.');
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        _showSnackBar('Khong the tao du lieu anh.');
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        byteData.buffer.asUint8List(),
        quality: 100,
        name: 'qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        HapticFeedback.mediumImpact();
        _showSnackBar('Da luu anh thanh cong vao thu vien.');
      } else {
        _showSnackBar(
          'Luu anh that bai: ${result['errorMessage'] ?? 'Khong ro nguyen nhan'}',
        );
      }
    } catch (error) {
      _showSnackBar('Da xay ra loi khi luu anh: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isIOS) {
      final PermissionStatus status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }

    final PermissionStatus photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted || photosStatus.isLimited) {
      return true;
    }

    final PermissionStatus storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  void _resetQrPosition() {
    if (_canvasSize == Size.zero) {
      return;
    }

    setState(() {
      _hasCustomQrPosition = false;
      _qrOffset = _centerOffsetFor(_canvasSize);
    });
  }

  void _resetEditor() {
    if (_canvasSize == Size.zero) {
      return;
    }

    setState(() {
      _hasCustomQrPosition = false;
      _qrCardSize = _defaultQrCardSize;
      _qrOffset = _centerOffsetFor(_canvasSize, qrSize: _defaultQrCardSize);
    });
  }

  void _syncCanvasSize(Size size) {
    if (_canvasSize == size) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final Offset nextOffset = _hasCustomQrPosition
          ? _clampOffset(_qrOffset, size, qrSize: _qrCardSize)
          : _centerOffsetFor(size, qrSize: _qrCardSize);

      setState(() {
        _canvasSize = size;
        _qrOffset = nextOffset;
      });
    });
  }

  Offset _centerOffsetFor(Size size, {double? qrSize}) {
    final double effectiveQrSize = qrSize ?? _qrCardSize;
    return Offset(
      math.max(0.0, (size.width - effectiveQrSize) / 2),
      math.max(0.0, (size.height - effectiveQrSize) / 2),
    );
  }

  Offset _clampOffset(Offset offset, Size size, {double? qrSize}) {
    final double effectiveQrSize = qrSize ?? _qrCardSize;
    final double maxDx = math.max(0.0, size.width - effectiveQrSize);
    final double maxDy = math.max(0.0, size.height - effectiveQrSize);

    return Offset(
      offset.dx.clamp(0.0, maxDx).toDouble(),
      offset.dy.clamp(0.0, maxDy).toDouble(),
    );
  }

  Offset _offsetForResizedQr({
    required Offset currentOffset,
    required Size size,
    required double oldSize,
    required double newSize,
    Offset translation = Offset.zero,
  }) {
    final Offset resizedOffset = currentOffset +
        translation -
        Offset((newSize - oldSize) / 2, (newSize - oldSize) / 2);

    return _clampOffset(resizedOffset, size, qrSize: newSize);
  }

  void _updateQrSize(double newSize) {
    final double previousSize = _qrCardSize;
    final double clampedSize = newSize.clamp(_minQrCardSize, _maxQrCardSize);

    setState(() {
      _qrCardSize = clampedSize;
      _qrOffset = _offsetForResizedQr(
        currentOffset: _qrOffset,
        size: _canvasSize,
        oldSize: previousSize,
        newSize: clampedSize,
      );
    });
  }

  void _updateQrTransform({
    required Size canvasSize,
    required double nextSize,
    required Offset translationDelta,
  }) {
    setState(() {
      _hasCustomQrPosition = true;
      _qrOffset = _offsetForResizedQr(
        currentOffset: _qrOffset,
        size: canvasSize,
        oldSize: _qrCardSize,
        newSize: nextSize,
        translation: translationDelta,
      );
      _qrCardSize = nextSize;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              colorScheme.primary.withValues(alpha: 0.18),
              const Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: _buildHeader(),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildGeneratePage(),
                    _buildComposePage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Tao QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Gan vao anh',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String title =
        _selectedIndex == 0 ? 'QR Generator' : 'QR Cover Editor';
    final String subtitle = _selectedIndex == 0
        ? 'Tao va xem ma QR rieng biet truoc khi dua vao anh.'
        : 'Gan QR vao anh bia, can chinh va luu thanh pham.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.qr_code_2, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildInputCard(),
      ],
    );
  }

  Widget _buildGeneratePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Ma QR',
                subtitle: 'Ban xem truoc QR truoc khi dua sang man gan anh.',
              ),
              const SizedBox(height: 20),
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 260,
                  height: 260,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigoAccent.withValues(alpha: 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _qrData.trim().isEmpty
                      ? Icon(
                          Icons.qr_code_2,
                          size: 108,
                          color: Colors.grey.shade300,
                        )
                      : QrImageView(
                          key: const ValueKey('qr-preview'),
                          data: _qrData,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _qrData.trim().isEmpty
                            ? 'Nhap link hoac noi dung bat ky de xem QR.'
                            : 'QR nay se duoc dung chung cho man gan vao anh.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Anh bia',
                subtitle: 'Chon anh nen va dieu chinh QR cho bo cuc dep hon.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _pickCoverImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _coverImageFile == null
                          ? 'Chon anh bia'
                          : 'Cap nhat anh bia',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetQrPosition,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Can giua QR'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetEditor,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildQrSizeSlider(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Preview thanh pham',
                subtitle:
                    'Keo va pinch QR de dat vi tri va kich thuoc phu hop.',
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _canvasAspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final Size size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        _syncCanvasSize(size);
                        return _buildPreviewCanvas(size);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _qrData.trim().isEmpty
                    ? 'Nhap link o phia tren de hien QR trong khung preview.'
                    : 'QR tu man Tao QR se duoc dung tai day.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveArtwork,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isSaving ? 'Dang luu anh...' : 'Luu anh thanh pham',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'https://example.com',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.link, color: Colors.indigoAccent),
        ),
        onChanged: (value) {
          setState(() {
            _qrData = value.trim();
          });
        },
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildQrSizeSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.zoom_out_map, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Kich thuoc QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_qrCardSize.round()} px',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('qr-size-slider'),
            value: _qrCardSize,
            min: _minQrCardSize,
            max: _maxQrCardSize,
            divisions: (_maxQrCardSize - _minQrCardSize).round(),
            label: '${_qrCardSize.round()}',
            onChanged: _updateQrSize,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCanvas(Size size) {
    final Offset visibleOffset = _clampOffset(
      _qrOffset,
      size,
      qrSize: _qrCardSize,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: RepaintBoundary(
        key: _captureKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverLayer(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
            if (_qrData.trim().isNotEmpty)
              Positioned(
                left: visibleOffset.dx,
                top: visibleOffset.dy,
                child: GestureDetector(
                  onScaleStart: (_) {
                    _scaleStartQrSize = _qrCardSize;
                  },
                  onScaleUpdate: (details) {
                    final double nextSize = (_scaleStartQrSize * details.scale)
                        .clamp(_minQrCardSize, _maxQrCardSize);

                    _updateQrTransform(
                      canvasSize: size,
                      nextSize: nextSize,
                      translationDelta: details.focalPointDelta,
                    );
                  },
                  child: _buildQrCard(),
                ),
              )
            else
              Center(
                child: Text(
                  'QR se hien o day',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverLayer() {
    if (_coverImageFile == null) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF312E81),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 72,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    return Image.file(
      _coverImageFile!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: Color(0xFF1E1B4B),
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildQrCard() {
    return Container(
      key: const ValueKey('qr-overlay'),
      width: _qrCardSize,
      height: _qrCardSize,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: QrImageView(
        data: _qrData,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}
