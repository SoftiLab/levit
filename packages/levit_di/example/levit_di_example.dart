import 'package:levit_di/levit_di.dart';

// A simple service
class DatabaseService extends LevitDisposable {
  bool connected = false;

  @override
  void onInit() {
    print('DatabaseService: Initializing...');
    connected = true;
  }

  @override
  void onClose() {
    print('DatabaseService: Closing...');
    connected = false;
  }

  void query(String sql) {
    if (!connected) throw Exception('Database not connected');
    print('DatabaseService: Executing "$sql"');
  }
}

// A dependent service
class UserRepository {
  // Dependencies are resolved seamlessly
  final db = Levit.find<DatabaseService>();

  void findUser(int id) {
    db.query('SELECT * FROM users WHERE id = $id');
  }
}

void main() {
  // 1. Register dependencies
  print('--- Registering ---');
  Levit.put(DatabaseService());
  Levit.lazyPut(() => UserRepository());

  // 2. Use dependencies
  print('\n--- Resolving ---');
  final repo = Levit.find<UserRepository>();
  repo.findUser(42);

  // 3. Clean up
  print('\n--- Cleaning up ---');
  Levit.reset(); // Disposes DatabaseService

  try {
    repo.findUser(42);
  } catch (e) {
    print('Error: $e');
  }
}
