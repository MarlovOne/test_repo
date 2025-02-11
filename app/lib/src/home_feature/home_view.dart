import 'package:flutter/material.dart';
import 'package:blabla/blabla.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  static const routeName = '/home';

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int a = 0;
  int b = 0;
  int factorialBase = 1;

  final TextEditingController _aController = TextEditingController(text: "0");
  final TextEditingController _bController = TextEditingController(text: "0");
  final TextEditingController _factorialController =
      TextEditingController(text: "1");

  @override
  void dispose() {
    _aController.dispose();
    _bController.dispose();
    _factorialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hello, World!',
            style: TextStyle(fontSize: 24),
          ),
          Text(
            'Sample lib verions: ${SampleLib.getVersion()}',
            style: TextStyle(fontSize: 20),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: _aController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      a = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              Text(' + '),
              SizedBox(
                width: 50,
                child: TextField(
                  textAlign: TextAlign.center,
                  controller: _bController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      b = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
              Text(' = '),
              Text(
                '${SampleLib.sum(a, b)}',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                child: TextField(
                  textAlign: TextAlign.end,
                  controller: _factorialController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      factorialBase = int.tryParse(value) ?? 1;
                    });
                  },
                ),
              ),
              Text(
                '! = ${SampleLib.factorial(factorialBase)}',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              SampleLib.processImage();
            },
            child: Text('Process Image'),
          )
        ],
      ),
    );
  }
}
