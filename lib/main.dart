import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const SimpleBrowserApp());
}

class StepsToReproduce extends StatelessWidget {
  const StepsToReproduce({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("1. Run the app."),
        Text("2. Tap on the '+' button to open a new tab."),
        Text("3. Tap on the 'X' button to close the tab."),
        Text("4. Exit app by pressing the back button."),
        Text("5. Observe the app crashes."),
      ],
    );
  }

  static void show(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Steps to reproduce'),
            content: const StepsToReproduce(),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              )
            ],
          );
        });
  }
}

class SimpleBrowserApp extends StatelessWidget {
  const SimpleBrowserApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const SimpleBrowser(),
    );
  }
}

class SimpleBrowser extends StatefulWidget {
  const SimpleBrowser({super.key});

  @override
  State<SimpleBrowser> createState() => _SimpleBrowserState();
}

class _SimpleBrowserState extends State<SimpleBrowser> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        StepsToReproduce.show(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TabManager(),
      builder: (context, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Builder(builder: (context) {
                    final manager = context.read<TabManager>();
                    final tab = context.select((TabManager manager) => manager.currentTab);
                    return InAppWebView(
                      key: ObjectKey(tab),
                      keepAlive: tab.keepAlive,
                      onWebViewCreated: tab.onTabWebviewCreated,
                      onTitleChanged: tab.onTabWebviewTitleChanged,
                      onUpdateVisitedHistory: tab.onTabHistoryChanged,
                      onLoadStop: (controller, url) async {
                        await tab.takeSnapshot();
                        manager.onSessionUpdated(tab);
                      },
                      onProgressChanged: (controller, progress) async {
                        await tab.takeSnapshot();
                        manager.onSessionUpdated(tab);
                      },
                      onScrollChanged: (controller, x, y) async {
                        await tab.takeSnapshot();
                        manager.onSessionUpdated(tab);
                      },
                    );
                  }),
                ),
                const SizedBox(
                  height: 16,
                ),
                const BrowserTabList(),
                const SizedBox(
                  height: 16,
                ),
                const BrowserToolbar(),
                const SizedBox(
                  height: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.select((TabManager manager) => manager.currentTab.state);
    final tabs = context.select((TabManager manager) => manager.tabs.map((e) => e.state).toList());
    final tabCount = tabs.length;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: tab.url),
              decoration: const InputDecoration(
                contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gapPadding: 0,
                ),
                hintText: 'Enter a URL',
                isDense: true,
                filled: true,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.go,
              onSubmitted: (url) {
                tab.session.load(url);
              },
            ),
          ),
          const SizedBox(
            width: 6,
          ),
          InkWell(
            customBorder: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).colorScheme.onBackground, width: 2),
                borderRadius: BorderRadius.circular(6)),
            child: Container(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                margin: const EdgeInsetsDirectional.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).colorScheme.onBackground, width: 2),
                ),
                child: Center(
                    child: Text(
                  tabCount.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ))),
            onTap: () {},
          )
        ],
      ),
    );
  }
}

class BrowserTabList extends StatelessWidget {
  const BrowserTabList({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = context.select((TabManager manager) => manager.tabs.map((e) => e.state)).toList();
    final selected = context.select((TabManager manager) => manager.currentTab.state);
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length + 1,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          if (index == tabs.length) {
            return AspectRatio(
              aspectRatio: 3 / 4,
              child: Card(
                child: InkWell(
                  onTap: () {
                    context.read<TabManager>().newTab();
                  },
                  child: const Center(
                    child: Icon(Icons.add),
                  ),
                ),
              ),
            );
          }
          return TabSnapshotWidget(tab: tabs[index], selected: tabs[index] == selected);
        },
      ),
    );
  }
}

class TabSnapshotWidget extends StatelessWidget {
  final SessionState tab;
  final bool selected;

  const TabSnapshotWidget({super.key, required this.tab, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onBackground,
                  width: 2),
              borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              context.read<TabManager>().switchTab(tab.session);
            },
            child: tab.snapshot != null
                ? Image.memory(
                    tab.snapshot!,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Text(
                      'No Snapshot',
                    ),
                  ),
          ),
        ),
      ),
      PositionedDirectional(
        top: 0,
        end: 0,
        child: IconButton(
            onPressed: () {
              context.read<TabManager>().closeTab(tab.session);
            },
            color: Theme.of(context).colorScheme.secondaryContainer,
            icon: Icon(
              Icons.close_rounded,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            )),
      )
    ]);
  }
}

class TabManager extends ChangeNotifier {
  List<Tab> tabs = [];
  late Tab currentTab;

  TabManager() {
    currentTab = Tab(manager: this);
    tabs.add(currentTab);
  }

  void newTab({String? initialUrl}) {
    final tab = Tab(manager: this)..initialUrl = initialUrl ?? "";
    tabs.add(tab);
    tabs = List.from(tabs);
    switchTab(tab);
    notifyListeners();
  }

  void switchTab(Tab tab) {
    currentTab = tab;
    notifyListeners();
  }

  void closeTab(Tab tab) {
    tabs.remove(tab);
    tabs = List.from(tabs);
    tab.close();
    if (tabs.isEmpty) {
      newTab();
    } else {
      switchTab(tabs.last);
    }
  }

  void onSessionUpdated(Tab tab) {
    tabs = List.from(tabs);
    notifyListeners();
  }
}

class Tab {
  final String id = UniqueKey().toString();
  final InAppWebViewKeepAlive keepAlive = InAppWebViewKeepAlive();
  final TabManager manager;
  InAppWebViewController? controller;
  late SessionState state = SessionState(session: this, title: '', url: '', snapshot: null);
  String initialUrl = "https://flutter.dev/";
  bool isCapturing = false;

  Tab({required this.manager});

  void onTabWebviewCreated(InAppWebViewController controller) async {
    this.controller = controller;
    await controller.clearHistory();
    if (initialUrl.isNotEmpty) {
      load(initialUrl);
    }
  }

  void onTabWebviewTitleChanged(InAppWebViewController controller, String? title) {
    state = state.copyWith(title: title ?? '');
    manager.onSessionUpdated(this);
  }

  void onTabHistoryChanged(InAppWebViewController controller, WebUri? url, bool? isReload) async {
    final uri = await controller.getUrl();
    state = state.copyWith(url: uri?.toString() ?? '');
    manager.onSessionUpdated(this);
  }

  void load(String url) {
    controller?.loadUrl(
        urlRequest: URLRequest(
      url: WebUri.uri(Uri.parse(url)),
    ));
  }

  void close() {
    // dispose keepalive to release webview
    // however this will cause app crashed when main activity destroyed
    InAppWebViewController.disposeKeepAlive(keepAlive);
  }

  Future<void> takeSnapshot() async {
    if (isCapturing) {
      return;
    }
    try {
      isCapturing = true;
      await Future.delayed(const Duration(milliseconds: 1000));
      final snapshot = await controller?.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          snapshotWidth: 400,
        ),
      );
      state = state.copyWith(snapshot: snapshot);
      manager.onSessionUpdated(this);
    } catch (e, s) {
      // ignored
    } finally {
      isCapturing = false;
    }
  }
}

class SessionState {
  final Tab session;
  final String title;
  final String url;
  final Uint8List? snapshot;

  SessionState({required this.session, required this.title, required this.url, required this.snapshot});

  SessionState copyWith({String? title, String? url, Uint8List? snapshot}) {
    return SessionState(
      session: session,
      title: title ?? this.title,
      url: url ?? this.url,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}
