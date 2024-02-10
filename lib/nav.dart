import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skilldrills/session.dart';
import 'package:skilldrills/main.dart';
import 'package:skilldrills/services/session.dart';
import 'package:skilldrills/services/utility.dart';
import 'package:skilldrills/tabs/drills.dart';
import 'package:skilldrills/tabs/profile.dart';
import 'package:skilldrills/services/factory.dart';
import 'package:skilldrills/tabs/Start.dart';
import 'package:skilldrills/tabs/drills/drill_detail.dart';
import 'package:skilldrills/tabs/profile/settings/settings.dart';
import 'package:skilldrills/widgets/basic_title.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:vibration/vibration.dart';
import 'package:skilldrills/nav_tab.dart';

final PanelController sessionPanelController = PanelController();

// This is the stateful widget that the main application instantiates.
class Nav extends StatefulWidget {
  const Nav({super.key});

  @override
  State<Nav> createState() => _NavState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _NavState extends State<Nav> {
  final lightLogo = SizedBox(
    height: 60,
    child: SvgPicture.asset(
      'assets/images/logo/SkillDrills.svg',
      semanticsLabel: 'Skill Drills',
    ),
  );

  // State variables
  PanelState _sessionPanelState = PanelState.CLOSED;
  double _bottomNavOffsetPercentage = 0;

  Widget? _title;
  List<Widget>? _actions;
  int _selectedIndex = 2;
  bool _showLogoToolbar = true;
  static final List<NavTab> _tabs = [
    NavTab(
      title: const BasicTitle(title: "Profile"),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: const Icon(
              Icons.settings,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(MaterialPageRoute(builder: (BuildContext context) {
                return const ProfileSettings();
              }));
            },
          ),
        ),
      ],
      body: const Profile(),
    ),
    const NavTab(
      title: BasicTitle(title: "History"),
    ),
    NavTab(
      title: const BasicTitle(title: "Start"),
      body: Start(
        sessionPanelController: sessionPanelController,
      ),
    ),
    NavTab(
      title: const BasicTitle(title: "Drills"),
      actions: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          child: IconButton(
            icon: const Icon(
              Icons.add,
              size: 28,
            ),
            onPressed: () {
              navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) {
                return const DrillDetail();
              }));
            },
          ),
        ),
      ],
      body: const Drills(),
    ),
    const NavTab(
      title: BasicTitle(title: "Routines"),
    ),
  ];

  void _onItemTapped(int index) async {
    await Vibration.hasAmplitudeControl().then((hasAmplitudeControl) => {
          if (settings.vibrate && hasAmplitudeControl! && index != _selectedIndex)
            {
              Vibration.vibrate(
                duration: 50,
                amplitude: 50,
              )
            }
        });

    setState(() {
      _selectedIndex = index;
      _title = index == 2 ? lightLogo : _tabs[index].title;
      _actions = _tabs[index].actions;
      _showLogoToolbar = (_tabs[index].title is Container) || index == 2;
    });
  }

  @override
  void initState() {
    setState(() {
      _title = lightLogo;
      _actions = [];
    });

    bootstrap();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SessionServiceProvider(
      service: sessionService,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: sessionService, // listen to ChangeNotifier
          builder: (context, child) {
            return SlidingUpPanel(
              backdropEnabled: true,
              controller: sessionPanelController,
              maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              minHeight: (sessionService.isRunning == true) ? 65 : 0,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              onPanelOpened: () {
                setState(() {
                  _sessionPanelState = PanelState.OPEN;
                });
              },
              onPanelClosed: () {
                setState(() {
                  _sessionPanelState = PanelState.CLOSED;
                });
              },
              onPanelSlide: (double offset) {
                setState(() {
                  _bottomNavOffsetPercentage = offset;
                });
              },
              panel: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  children: [
                    ListTile(
                      tileColor: Theme.of(context).primaryColor,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Wednesday Session",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                              fontFamily: "Choplin",
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                printDuration(sessionService.currentDuration),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  fontFamily: "Choplin",
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: InkWell(
                        child: Icon(
                          _sessionPanelState == PanelState.CLOSED ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                      onTap: () {
                        if (sessionPanelController.isPanelClosed) {
                          sessionPanelController.open();
                          setState(() {
                            _sessionPanelState = PanelState.OPEN;
                          });
                        } else {
                          sessionPanelController.close();
                          setState(() {
                            _sessionPanelState = PanelState.CLOSED;
                          });
                        }
                      },
                    ),
                    Session(
                      sessionPanelController: sessionPanelController,
                    ),
                  ],
                ),
              ),
              body: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      collapsedHeight: _showLogoToolbar ? 100 : 65,
                      expandedHeight: _showLogoToolbar ? 200.0 : 140,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      iconTheme: Theme.of(context).iconTheme,
                      actionsIconTheme: Theme.of(context).iconTheme,
                      floating: true,
                      pinned: true,
                      flexibleSpace: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _showLogoToolbar ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.background,
                        ),
                        child: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          titlePadding: _showLogoToolbar ? const EdgeInsets.only(left: 10, right: 10, bottom: 20, top: 20) : null,
                          centerTitle: _showLogoToolbar ? true : false,
                          title: _title,
                          background: Container(
                            color: _showLogoToolbar ? Theme.of(context).primaryColor : Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                      actions: _actions,
                    ),
                  ];
                },
                body: _sessionPanelState == PanelState.OPEN
                    ? Container(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: _tabs.elementAt(_selectedIndex),
                      )
                    : _tabs.elementAt(_selectedIndex),
              ),
            );
          },
        ),
        bottomNavigationBar: SizedOverflowBox(
          alignment: AlignmentDirectional.topCenter,
          size: Size.fromHeight(AppBar().preferredSize.height - (AppBar().preferredSize.height * _bottomNavOffsetPercentage)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add),
                label: 'Start',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.timer),
                label: 'Drills',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note),
                label: 'Routines',
              ),
            ],
            currentIndex: _selectedIndex,
            backgroundColor: Theme.of(context).colorScheme.background,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Theme.of(context).colorScheme.onPrimary,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
