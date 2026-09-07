import '../models/organizer_data.dart';

abstract interface class TaskRepository {
  Future<OrganizerData> loadData();
  Future<void> saveData(OrganizerData data);
}
