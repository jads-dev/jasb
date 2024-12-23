GRANT USAGE ON SCHEMA ${flyway:defaultSchema} TO ${user};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${flyway:defaultSchema} TO ${user};
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${flyway:defaultSchema} TO ${user};
