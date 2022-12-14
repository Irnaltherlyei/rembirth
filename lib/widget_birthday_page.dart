import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hello_flutter/persistence.dart';
import 'package:hello_flutter/widget_birthday_input.dart';

import 'date.dart';
import 'notifications.dart';
import 'widget_birthday_entry.dart';
import 'birthday_entry.dart';

class WidgetBirthdayPage extends StatefulWidget {
  const WidgetBirthdayPage({Key? key}) : super(key: key);

  @override
  State<WidgetBirthdayPage> createState() => _WidgetBirthdayPageState();
}

class _WidgetBirthdayPageState extends State<WidgetBirthdayPage>{

  BirthdayEntry? selected;

  late Persistence persistence;
  late Notifications notifications;

  @override
  void initState() {
    persistence = Persistence();
    persistence.init();

    notifications = Notifications();
    notifications.initNotifications();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails details){
          setState((){
            selected = null;
          });
        },
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<BirthdayEntry>>(
                  future: fetchBirthdayEntries(),
                  builder: (context, future){
                    if(!future.hasData) {
                      return Container();
                    } else {
                      List<BirthdayEntry>? list = future.data;
                      // TODO: Move this to initialization
                      updateNotifications(list!);
                      list.sort((a, b) => Date.daysToBirthday(a.getDate()).compareTo(Date.daysToBirthday(b.getDate())));
                      return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index){
                            return WidgetBirthdayEntry(
                                entry: list[index],
                                onLongPress: () {
                                  setState(() {
                                    selected = list[index];
                                  });
                                },
                            );
                          }
                      );
                    }
                  }
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: Row(
            children: [
              selected != null ? FloatingActionButton(
                onPressed: () {
                  _editEntry(context, selected!);
                },
                tooltip: 'Edit',
                child: const Icon(Icons.edit),
              ) : Container(),
              Expanded(child: Container()),
              selected != null ? FloatingActionButton(
                onPressed: () {
                  deleteBirthdayEntry(selected!);
                  selected = null;
                },
                tooltip: 'Delete',
                child: const Icon(Icons.delete),
              ) : Container(),
              Expanded(child: Container()),
              selected == null ? FloatingActionButton(
                onPressed: () {
                  _addEntry(context);
                },
                tooltip: 'Add',
                child: const Icon(Icons.add),
              ) :  FloatingActionButton(
                onPressed: () {
                  setState(() {
                    selected = null;
                  });
                },
                tooltip: 'Cancel',
                child: const Icon(Icons.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void updateNotifications(List<BirthdayEntry> entries) async{
    List<PendingNotificationRequest> pendingNotificationRequests = await notifications.flutterLocalNotificationsPlugin.pendingNotificationRequests();

    for(BirthdayEntry entry in entries){
      if(pendingNotificationRequests.any((notification) => notification.id == entry.hashCode)){
        // Do nothing
      } else {
        // Schedule notification
        notifications.scheduleNotification(
          entry.hashCode,
          "Birthday",
          'Today is ${entry.name}\'s birthday.',
          Date.now().add(Duration(days: Date.daysToBirthday(entry.getDate()))));
      }
    }
  }

  Future<List<BirthdayEntry>> fetchBirthdayEntries() async {
    final entries = await persistence.getAllEntries();

    List<BirthdayEntry> fetchedEntries = entries.map((BirthdayEntry item) => BirthdayEntry(
        name: item.toMap()['name'],
        date: item.toMap()['date'],
      ),
    ).toList();

    return fetchedEntries;
  }

  Future<void> _addEntry(BuildContext context) async{
    final entry = await Navigator.push(
        context,
        DialogRoute(builder: (context) => const WidgetBirthdayInput(), context: context),
    );

    if(!mounted) return;

    if(entry is! BirthdayEntry) return;

    addBirthdayEntry(entry);
  }

  Future<void> _editEntry(BuildContext context, BirthdayEntry selected) async{
    final entry = await Navigator.push(
      context,
      DialogRoute(builder: (context) => WidgetBirthdayInput(entry: selected), context: context),
    );

    if(!mounted) return;

    if(entry is! BirthdayEntry) return;

    editBirthdayEntry(selected, entry);
  }

  bool validateBirthdayEntry(BirthdayEntry entry){
    // Name can't be blank.
    if(entry.name.isEmpty){
      return false;
    }
    // Name has less than 32 characters.
    if(entry.name.length > 32){
      return false;
    }
    return true;
  }

  void deleteBirthdayEntry(BirthdayEntry entry){
    setState(() {
      persistence.deleteEntry(entry);
      notifications.deleteScheduledNotification(entry.hashCode);
    });
  }

  void addBirthdayEntry(BirthdayEntry entry) {
    if(!validateBirthdayEntry(entry)) return;

    setState(() {
      persistence.insertEntry(entry);
      notifications.scheduleNotification(
          entry.hashCode,
          "Birthday",
          'Today is ${entry.name}s birthday.',
          Date.now().add(Duration(days: Date.daysToBirthday(entry.getDate()))));
    });
  }

  void editBirthdayEntry(BirthdayEntry selected, BirthdayEntry entry){
    if(!validateBirthdayEntry(entry)) return;

    setState(() {
      persistence.updateEntry(selected, entry);
    });
  }
}