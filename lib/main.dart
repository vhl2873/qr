import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
          surface: const Color(0xFF0F172A),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: const QRScreen(),
    );
  }
}

class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();
  String _qrData = "";
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveQR() async {
    if (_qrData.isEmpty) {
      _showSnackBar("Vui lòng nhập link trước!");
      return;
    }

    setState(() => _isSaving = true);

    try {
      PermissionStatus status;
      if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        // Android 11+ handles storage differently, but image_gallery_saver often handles it.
        // For older Android, WRITE_EXTERNAL_STORAGE is needed.
        status = await Permission.storage.request();
      }

      if (!status.isGranted) {
        _showSnackBar("Chưa cấp quyền lưu ảnh. Vui lòng kiểm tra cài đặt.");
        setState(() => _isSaving = false);
        return;
      }

      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );

      if (image != null) {
        final result = await ImageGallerySaverPlus.saveImage(
          image,
          quality: 100,
          name: "qr_${DateTime.now().millisecondsSinceEpoch}",
        );

        if (result != null && result['isSuccess'] == true) {
          HapticFeedback.mediumImpact();
          _showSnackBar("Đã lưu QR vào thư viện ảnh ✨");
        } else {
          _showSnackBar("Lỗi khi lưu ảnh: ${result?['errorMessage'] ?? 'Không rõ'}");
        }
      }
    } catch (e) {
      _showSnackBar("Đã xảy ra lỗi: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surface.withBlue(60),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  "QR Generator",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Dán link để tạo mã QR siêu nhanh",
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Input Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "https://example.com",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.link, color: Colors.indigoAccent),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _qrData = value;
                      });
                    },
                  ),
                ),
                
                const Spacer(),

                // QR Display Section
                Center(
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigoAccent.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: _qrData.isEmpty
                        ? Container(
                            width: 200,
                            height: 200,
                            child: Icon(Icons.qr_code_2, size: 100, color: Colors.grey[300]),
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200.0,
                            gapless: true,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                    ),
                  ),
                ),

                const Spacer(),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveQR,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 8,
                    shadowColor: Colors.indigoAccent.withOpacity(0.5),
                  ),
                  child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded),
                          SizedBox(width: 12),
                          Text("Lưu vào thư viện ảnh", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
