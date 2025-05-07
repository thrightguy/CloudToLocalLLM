A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.

## Postgres Query Result Row Type

For postgres >=3.0.0 (including 3.5.6), use `ResultRow` as the type for rows returned from queries, not `PostgreSQLResultRow`.

If you see errors like `Undefined class 'PostgreSQLResultRow'`, update your model factory constructors to use `ResultRow` from `package:postgres/postgres.dart`.

Example:
```dart
import 'package:postgres/postgres.dart';

factory User.fromRow(ResultRow row) { ... }
```

## Postgres 3.5.6 Connection API Migration

- Use `Connection.open` and `Endpoint` to create a database connection.
- Use `conn.execute` for all queries (including SELECT, INSERT, UPDATE, DELETE).
- For named parameters, use `Sql.named('...')` and pass parameters as a map via the `parameters` argument.
- To check affected rows, use `result.affectedRows`.

### Example
```dart
final conn = await Connection.open(
  Endpoint(
    host: 'localhost',
    database: 'postgres',
    username: 'user',
    password: 'pass',
  ),
  settings: ConnectionSettings(sslMode: SslMode.disable),
);

final result = await conn.execute(
  Sql.named('SELECT * FROM users WHERE id = @id'),
  parameters: {'id': 'some-id'},
);
if (result.affectedRows > 0) {
  // Success
}
```

### Troubleshooting
- If you see errors about `query` or `substitutionValues`, update to use `execute`, `Sql.named`, and `parameters` as above.
- If you see errors about the operator '>' not being defined for 'Result', use `result.affectedRows > 0` instead.

### Troubleshooting Docker Build

If the Docker container fails to start due to missing ./bin/server:
- Run `dart pub get` to ensure dependencies are installed.
- Run `dart compile exe bin/auth_service.dart -o bin/server` to check for build errors.
- Check Docker build logs for errors during the compile step:
  ```bash
  docker-compose -f docker-compose.web.yml build auth
  ```
- Fix any Dart errors and retry the build.
