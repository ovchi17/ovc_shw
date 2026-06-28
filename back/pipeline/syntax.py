from pipeline._utils import  calculate_score_plateau

SPACY_MODEL = "ru_core_news_sm"

try:
    import spacy

    _nlp = spacy.load(SPACY_MODEL)
except OSError:
    raise RuntimeError(
        f"\nSpaCy модель '{SPACY_MODEL}' не найдена.\n"
        f"Установите командой:\n    python -m spacy download {SPACY_MODEL}\n"
    )

WEIGHTS = {
    "mean_utterance_length": 0.30,
    "embedding_depth": 0.30,
    "mean_dep_distance": 0.20,
    "clauses_per_sentence": 0.10,
    "complex_sentences_ratio": 0.10,
}


def token_depth(token) -> int:
    depth = 0
    current = token
    while current.head != current and depth < 50:
        current = current.head
        depth += 1
    return depth


def count_clauses(sent) -> int:
    clause_count = 0
    for token in sent:
        if token.pos_ in {"VERB", "AUX"} and token.dep_ not in {"mark", "cc", "punct"}:
            verb_form = token.morph.get("VerbForm")
            if verb_form and verb_form[0] in {"Inf", "Part", "Conv"}:
                continue
            clause_count += 1
    return max(1, clause_count)


def is_complex_sentence(sent) -> bool:
    return count_clauses(sent) > 1


def compute_syntax_metrics(text: str) -> dict:
    if not text or not text.strip():
        return {"error": "Пустой текст для синтаксического анализа"}

    doc = _nlp(text)
    sentences = [sent for sent in doc.sents if len([t for t in sent if not t.is_punct]) >= 4]

    if not sentences:
        return {"error": "Не удалось выделить достаточное количество предложений"}

    word_counts = []
    depths = []
    dep_dists = []
    clause_counts = []
    complex_count = 0
    dep_types = set()

    for sent in sentences:
        tokens = [t for t in sent if not t.is_punct and not t.is_space]
        if not tokens:
            continue

        word_counts.append(len(tokens))
        max_depth = max(token_depth(t) for t in tokens)
        depths.append(max_depth)
        for t in tokens:
            if t.dep_ != "ROOT" and t.head != t:
                dep_dists.append(abs(t.i - t.head.i))
            dep_types.add(t.dep_)
        clauses = count_clauses(sent)
        clause_counts.append(clauses)

        if is_complex_sentence(sent):
            complex_count += 1

    total_sents = len(word_counts)
    total_tokens = sum(word_counts)

    if total_tokens < 30:
        return {"error": f"Недостаточно текста для анализа синтаксиса (слов: {total_tokens}, нужно ≥30)"}

    mean_utterance_length = sum(word_counts) / total_sents if total_sents > 0 else 0.0
    embedding_depth = sum(depths) / total_sents if total_sents > 0 else 0.0
    mean_dependency_distance = sum(dep_dists) / len(dep_dists) if dep_dists else 0.0
    clauses_per_sentence = sum(clause_counts) / total_sents if total_sents > 0 else 0.0
    complex_sentences_ratio = (complex_count / total_sents * 100) if total_sents > 0 else 0.0
    syntactic_type_count = len(dep_types)

    return {
        "mean_utterance_length": mean_utterance_length,
        "embedding_depth": embedding_depth,
        "mean_dependency_distance": mean_dependency_distance,
        "clauses_per_sentence": clauses_per_sentence,
        "complex_sentences_ratio": complex_sentences_ratio,
        "syntactic_type_count": syntactic_type_count,
    }


def analyze(tr: dict) -> dict:
    full_text = tr.get("text", "")
    if not full_text:
        segments = [seg.get("text", "") for seg in tr.get("segments", []) if seg.get("text", "").strip()]
        full_text = " ".join(segments)

    metrics = compute_syntax_metrics(full_text)

    if "error" in metrics:
        return metrics

    mul = metrics["mean_utterance_length"]
    ed = metrics["embedding_depth"]
    mdd = metrics["mean_dependency_distance"]
    cps = metrics["clauses_per_sentence"]
    csr = metrics["complex_sentences_ratio"]
    s_mul = calculate_score_plateau(mul, opt_low=8, opt_high=15, low=3.0, high=25)
    s_ed = calculate_score_plateau(ed, opt_low=2, opt_high=5.0, low=1, high=10.0)
    s_mdd = calculate_score_plateau(mdd, opt_low=2, opt_high=4.0, low=1, high=8.0)
    s_cps = calculate_score_plateau(cps, opt_low=1.5, opt_high=2, low=0.8, high=5.0)
    s_csr = calculate_score_plateau(csr, opt_low=20.0, opt_high=40.0, low=0.0, high=80.0)

    final_score = round(
        WEIGHTS["mean_utterance_length"] * s_mul +
        WEIGHTS["embedding_depth"] * s_ed +
        WEIGHTS["mean_dep_distance"] * s_mdd +
        WEIGHTS["clauses_per_sentence"] * s_cps +
        WEIGHTS["complex_sentences_ratio"] * s_csr
    )

    return {
        "mean_utterance_length": round(mul, 2),
        "embedding_depth": round(ed, 3),
        "mean_dependency_distance": round(mdd, 3),
        "clauses_per_sentence": round(cps, 2),
        "complex_sentences_ratio": round(csr, 2),
        "syntactic_type_count": metrics["syntactic_type_count"],
        "score_mean_utterance_length": round(s_mul, 1),
        "score_embedding_depth": round(s_ed, 1),
        "score_mean_dep_distance": round(s_mdd, 1),
        "score_clauses_per_sentence": round(s_cps, 1),
        "score_complex_sentences_ratio": round(s_csr, 1),
        "score": final_score,
    }
