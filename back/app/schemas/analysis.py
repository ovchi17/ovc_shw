from __future__ import annotations
from pydantic import BaseModel


class RadarData(BaseModel):
    parasites: int
    pauses: int
    tempo: int
    lexical: int
    syntax: int


class Parameter(BaseModel):
    key: str
    title: str
    score: int
    icon: str
    description: str


class Timecode(BaseModel):
    type: str
    start: float
    end: float | None
    description: str


class FillerPieItem(BaseModel):
    word: str
    percent: int
    count: int


class PauseHistogram(BaseModel):
    brief: int
    medium: int
    long: int


class PauseStats(BaseModel):
    brief_count: int
    medium_count: int
    long_count: int
    long_total_seconds: float


class ParasiteDetail(BaseModel):
    score: int
    filler_count: int
    filler_pct: float
    filler_density: float = 0.0
    unique_types: int = 0
    max_consecutive: int = 0
    score_filler_proc: float = 0.0
    score_density: float = 0.0
    score_unique: float = 0.0
    score_consecutive: float = 0.0
    top_fillers: list[dict]
    personal_fillers: list[dict]
    top_fillers_overall: list[dict]


class PausesDetail(BaseModel):
    score: int
    ptr: float
    speech_rate: float
    artic_rate: float
    mlr: float
    brief_pause_count: int = 0
    medium_pause_count: int = 0
    long_pause_count: int
    filled_pause_count: int
    max_pause_ms: int
    filled_rate: float = 0.0
    medium_pause_pct: float = 0.0
    long_pause_pct: float = 0.0
    score_ptr: float = 0.0
    score_mlr: float = 0.0
    score_long_pct: float = 0.0
    score_max_pause: float = 0.0
    score_medium_pct: float = 0.0
    score_filled: float = 0.0


class TempoDetail(BaseModel):
    score: int
    window_cv: float
    window_sr_mean: float
    window_sr_min: float
    window_sr_max: float
    window_count: int
    speech_rate: float = 0.0
    articulation_rate: float = 0.0
    score_cv: float = 0.0
    score_speech_rate: float = 0.0
    score_articulation_rate: float = 0.0


class LexicalDetail(BaseModel):
    score: int
    mattr: float
    mtld: float
    top_repeat_pct: float
    top_repeated_words: list[str]
    score_mattr: float = 0.0
    score_mtld: float = 0.0
    score_top_repeat_pct: float = 0.0


class SyntaxDetail(BaseModel):
    score: int
    mean_utterance_length: float
    embedding_depth: float
    clauses_per_sentence: float = 0.0
    complex_sentences_ratio: float = 0.0
    syntactic_variety: float = 0.0
    mean_dependency_distance: float = 0.0
    syntactic_type_count: int = 0
    score_mean_utterance_length: float = 0.0
    score_embedding_depth: float = 0.0
    score_mean_dep_distance: float = 0.0
    score_clauses_per_sentence: float = 0.0
    score_complex_sentences_ratio: float = 0.0


class AnalysisDetail(BaseModel):
    id: int
    overall_score: int
    duration_sec: float
    transcript: str | None
    created_at: str
    audio_url: str | None = None
    processing_times: dict | None = None
    radar: RadarData
    parameters: list[Parameter]
    filler_pie: list[FillerPieItem]
    pause_histogram: PauseHistogram
    pause_stats: PauseStats
    timecodes: list[Timecode]
    parasites: ParasiteDetail
    pauses: PausesDetail
    tempo: TempoDetail
    lexical: LexicalDetail
    syntax: SyntaxDetail
