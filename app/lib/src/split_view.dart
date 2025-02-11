import 'package:flutter/material.dart';

class SplitView extends StatefulWidget {
  final Widget title;
  final Widget panel;
  final Widget child;

  const SplitView({
    super.key,
    required this.title,
    required this.panel,
    required this.child,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  bool isOpen = false;

  bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  IconButton _buildToggleButton() {
    return IconButton(
      onPressed: () {
        setState(() {
          isOpen = !isOpen;
        });
      },
      icon: Icon(isOpen ? Icons.visibility_off : Icons.visibility),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: widget.title,
      leading: isMobile(context) ? null : _buildToggleButton(),
    );
  }

  Widget _buildSplitView() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          Visibility(
            visible: isOpen,
            child: SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(child: widget.panel),
                  const VerticalDivider(
                    width: 1,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: widget.child,
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: widget.panel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isMobile(context) ? _buildDrawer(context) : _buildSplitView();
  }
}
