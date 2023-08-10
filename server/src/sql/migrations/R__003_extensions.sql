ALTER SYSTEM SET pg_trgm.strict_word_similarity_threshold = 0.15;
SELECT pg_reload_conf();
