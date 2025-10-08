# Node.js Directory Structure

## Question: Is `src/main/java` used in Node.js projects?

**Short answer:** No, `src/main/java` is a Java/Maven convention. Node.js uses simpler directory structures.

## Java/Maven Convention
```
project/
└── src/
    ├── main/
    │   ├── java/              # Production Java code
    │   └── resources/         # Production resources
    └── test/
        ├── java/              # Test Java code
        └── resources/         # Test resources
```

## Node.js Convention (What We Use)

```
project/
├── src/                       # All source code
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── services/
│   └── index.js              # Entry point
├── test/                      # Tests (optional)
│   └── *.test.js
├── dist/                      # Build output
└── package.json
```

**OR** the simpler variant:
```
project/
├── lib/                       # Source code
├── test/                      # Tests
└── package.json
```

## Our Project Structure

We're using the standard Node.js convention:

```
server/
├── src/                       ✅ Standard Node.js
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── services/
│   ├── app.js
│   └── lambda.js
├── dist/                      ✅ Build output
├── package.json               ✅ Standard
└── build.sh
```

## Why Node.js is Simpler

**Java/Maven needs deep nesting because:**
- Separate source sets (main, test)
- Language-specific directories (java, resources)
- Build tool conventions (Maven/Gradle)

**Node.js doesn't need this because:**
- Tests go in `test/` or alongside source as `*.test.js`
- No separate "resources" directory (everything is JavaScript/JSON)
- Simpler build tools (npm, webpack)

## Common Node.js Patterns

### 1. Simple Projects
```
project/
├── index.js
├── lib/
└── package.json
```

### 2. Medium Projects (What we use)
```
project/
├── src/
│   ├── controllers/
│   ├── models/
│   └── services/
└── package.json
```

### 3. Large Projects
```
project/
├── src/
│   ├── api/
│   │   ├── controllers/
│   │   └── routes/
│   ├── domain/
│   │   ├── models/
│   │   └── services/
│   └── infrastructure/
│       ├── database/
│       └── messaging/
└── package.json
```

## Conclusion

Our directory structure (`server/src/`) is **correct and follows Node.js best practices**.

- ✅ `src/` for source code
- ✅ `dist/` for build output
- ✅ No `main/` subdirectory needed
- ✅ Clean and simple

You can use this structure with confidence!
