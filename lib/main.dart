import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

// Global Camera object
List<CameraDescription> cameras;

//main load function: async because of camera initiations
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }
  runApp(new MyApp());
}

// stateless widget to load main home widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tflite real-time classification',
      home: HomePage(cameras),
    );
  }
}


class HomePage extends StatefulWidget {
  // private camera object: get assigned to global one
  final List<CameraDescription> cameras;
  HomePage(this.cameras);
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController controller;
  var recognitions;
  int whichCamera = 0;

  // load tflite model for deeplab v3
  loadModel() async {
    String res;
    res = await Tflite.loadModel(
      model: "assets/deeplabv3_257_mv_gpu.tflite",
      labels: "assets/deeplabv3_257_mv_gpu.txt",
    );
    print(res);
  }

  // initiate camera controller
  void initiateCamera(int whichCamera) {
    this.controller = new CameraController( widget.cameras[whichCamera], ResolutionPreset.low);
    if (widget.cameras == null || widget.cameras.length < 1) {
      print('No camera is found');
    } else {
      this.controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
        this.controller.startImageStream((CameraImage img) {
          Tflite.runSegmentationOnFrame(
              bytesList: img.planes.map((plane) {return plane.bytes;}).toList(),// required
              imageHeight: img.height, // defaults to 1280
              imageWidth: img.width,   // defaults to 720
              imageMean: 127.5,        // defaults to 0.0
              imageStd: 127.5,         // defaults to 255.0
              rotation: 90,            // defaults to 90, Android only
              outputType: "png",       // defaults to "png"
              asynch: true             // defaults to true
          ).then((rec) {
            setState(() {
              this.recognitions = rec;
            });
          });
        });
      });
    }
  }

  // widget for rendering the realtime camera on screen
  Widget cameraShow() {
    if (this.controller == null || !this.controller.value.isInitialized) {
      return Container(
        child: Text("Not inialized"),
      );
    }

    var tmp = MediaQuery.of(context).size;
    var screenW;
    var screenH;

    if(tmp == null) {
      screenW = 0;
    }else {
      screenW = tmp.width;
      screenH = tmp.height;
      tmp = this.controller.value.previewSize;
    }

    return Container(
      child: CameraPreview(this.controller),
      constraints: BoxConstraints(
        maxHeight: 550,
        maxWidth: screenW,
      )  ,
    );
  }

  Widget renderSegmentPortion() {
    if(this.whichCamera == 2) {
      return RotatedBox(
        quarterTurns: 2,
        child: Image.memory(this.recognitions, fit: BoxFit.fill),
      );
    }else {
      return Image.memory(this.recognitions, fit: BoxFit.fill);
    }
  }

  // widget for segmentation renders
  Widget segmentationResults() {
    return Opacity(
      opacity: 0.4,
      child: this.recognitions == null ? Center(child: Text('Not initialized'),): renderSegmentPortion(),
    );
  }

  // gets called when widget is initiated
  @override
  void initState() {
    super.initState();
    loadModel();
    initiateCamera(this.whichCamera);
  }

  // gets called when the widget comes to an end
  @override
  void dispose() {
    this.controller?.dispose();
    super.dispose();
  }

  // gets called everytime the widget need to re-render or build
  @override
  Widget build(BuildContext context) {

    var tmp = MediaQuery.of(context).size;
    var screenW;
    var screenH;

    if(tmp == null) {
      screenW = 0;
    }else {
      screenW = tmp.width;
      screenH = tmp.height;
      tmp = this.controller.value.previewSize;
    }

    setState(() {});
    return Scaffold(
      appBar: AppBar( centerTitle: true,title: const Text('Real time Segmentation')),
      floatingActionButton: Stack(
        children: <Widget>[
          Padding(padding: EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FloatingActionButton(
                child: Icon(Icons.people),
                tooltip: 'Selfie camera',
                backgroundColor: Colors.redAccent,
                onPressed: () {
                  setState(() {
                    this.whichCamera = 2;
                  });
                  initiateCamera(this.whichCamera);
                },
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                child: Icon(Icons.camera),
                tooltip: 'Main camera',
                backgroundColor: Colors.redAccent,
                onPressed: () {
                  setState(() {
                    this.whichCamera = 0;
                  });
                  initiateCamera(this.whichCamera);
                },
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: cameraShow(),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: screenW,
            height: 550,
            child: segmentationResults(),
          ),
        ],
      ),
    );
  }
}






