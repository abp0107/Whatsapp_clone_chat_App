import 'package:flutter/material.dart';

class LoadingWrapper extends StatelessWidget {
  final bool isLoading;
  final Future<void> Function()? onRefresh;
  final Widget child;

  const LoadingWrapper({
    Key? key,
    required this.isLoading,
    this.onRefresh,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(onRefresh: onRefresh ?? () async {}, child: child),
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

bool isLoading = false;
