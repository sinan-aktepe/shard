// Public testing utilities for the shard package.
//
// Import from your test code:
//
//   import 'package:shard/shard_test.dart';
//
// This entry point is intentionally separate from `package:shard/shard.dart`
// so production builds do not link the test utilities. Nothing in
// `lib/shard.dart`'s import graph imports this file.
export 'src/testing/testing.dart';
