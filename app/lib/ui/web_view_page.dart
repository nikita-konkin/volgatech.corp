import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

/// Generic in-app web screen used for «Почта» (OWA) and «Портал». Loads the web
/// login inside a WebView so the session lives in the app — the WebView keeps
/// only the site's session cookie, never the password (same trust model as a
/// browser tab).
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    // Platform-channel calls run in order; nothing needs their results.
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_controller.setBackgroundColor(Colors.white));
    unawaited(_controller.setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = false;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame == true && mounted) {
            setState(() {
              _error = true;
              _loading = false;
            });
          }
        },
    )));
    unawaited(_controller.loadRequest(Uri.parse(widget.url)));
  }

  Future<void> _reload() async {
    setState(() {
      _error = false;
      _loading = true;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser() async {
    await launchUrl(Uri.parse(widget.url),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
            ),
            IconButton(
              tooltip: 'Открыть в браузере',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openInBrowser,
            ),
          ],
          bottom: (_loading && _progress < 100)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: _error ? _errorView() : WebViewWidget(controller: _controller),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Brand.muted(context)),
            const SizedBox(height: 12),
            Text('Не удалось загрузить страницу',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted(context))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                    onPressed: _reload, child: const Text('Повторить')),
                TextButton(
                    onPressed: _openInBrowser,
                    child: const Text('Открыть в браузере')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
