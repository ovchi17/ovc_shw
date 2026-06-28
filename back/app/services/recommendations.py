from sqlalchemy.orm import Session
from app.models.recommendation import Recommendation
from app.models.recording import AnalysisResult


def get_tips_and_exercises(db: Session, result: AnalysisResult) -> dict:
    scores = {
        "parasites": getattr(result, "score_parasites", 0) or 0,
        "pauses":    getattr(result, "score_pauses",    0) or 0,
        "tempo":     getattr(result, "score_tempo",     0) or 0,
        "lexical":   getattr(result, "score_lexical",   0) or 0,
        "syntax":    getattr(result, "score_syntax",    0) or 0,
    }
    ordered_categories = sorted(scores.keys(), key=lambda k: scores[k])
    tips = []
    tip_id = 1
    for category in ordered_categories:
        recommendations = (
            db.query(Recommendation)
            .filter(Recommendation.category == category)
            .order_by(Recommendation.id)
            .all()
        )

        for rec in recommendations:
            tips.append({
                "id": tip_id,
                "category": category,
                "title": rec.title,
                "body": rec.body,
                "source": rec.source,
                "is_personalized": True,
            })
            tip_id += 1

    return {"tips": tips}