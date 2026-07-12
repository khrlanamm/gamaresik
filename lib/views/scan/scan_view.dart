import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/scan_viewmodel.dart';
import '../result/result_view.dart';

class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  late ScanViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ScanViewModel();
    _viewModel.initializeCamera();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(title: const Text('Scan Waste')),
        body: Consumer<ScanViewModel>(
          builder: (context, vm, child) {
            if (!vm.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              children: [
                CameraPreview(vm.controller!),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: () async {
                        final image = await vm.takePicture();
                        if (image != null && context.mounted) {
                          // Show loading overlay
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );
                          
                          // Simulate processing
                          await Future.delayed(const Duration(seconds: 2));
                          
                          if (context.mounted) {
                            Navigator.pop(context); // Pop loading
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultView(imagePath: image.path),
                              ),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.camera),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
