#!/usr/bin/env python3
"""1:1 Python port of Blob's pure logic, verified in this sandbox.

Covers: Blobatar determinism, speaker segmentation, todo extraction,
local summarizer. The Swift counterparts must stay behaviorally identical.
"""
import math, unittest
from datetime import date

# ---------- Blobatar (port of Blobatar.swift) ----------

def fnv1a_stream(name: str):
    h = 0x811c9dc5
    for b in name.strip().lower().encode():
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    out = []
    x = h if h else 0x9e3779b9
    for _ in range(8):
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        out.append(x)
    return out

def unit(v): return (v % 10000) / 10000.0

def blobatar_traits(name: str):
    s = fnv1a_stream(name)
    silhouette = s[0] % 10
    hue = unit(s[1])
    accent = (hue + 0.5 + unit(s[2]) * 0.15) % 1.0
    eye = s[3] % 4
    mouth = unit(s[4]) * 2 - 1
    cheeks = s[5] % 2 == 0
    gaze = unit(s[6])
    return dict(silhouette=silhouette, hue=hue, accent=accent, eye=eye,
                mouth=mouth, cheeks=cheeks, gaze=gaze)

# ---------- SpeakerSegmenter (port) ----------

class Turn:
    def __init__(self, tid, text, start, end, energy, pace, speaker):
        self.id, self.text, self.start, self.end = tid, text, start, end
        self.energy, self.pace, self.speaker = energy, pace, speaker

class SpeakerSegmenter:
    def __init__(self, turn_gap=1.4, new_speaker_distance=1.1):
        self.turns = []
        self.profiles = []
        self.turn_gap = turn_gap
        self.new_speaker_distance = new_speaker_distance
        self._next_turn = 0
        self._next_speaker = 0

    def _dist(self, p, energy, pace):
        return abs(energy - p["meanEnergy"]) / 0.25 + abs(pace - p["meanPace"]) / 1.5

    def add_chunk(self, start, end, text, energy, pace):
        text = text.strip()
        if not text:
            return None
        merged = False
        speaker = None
        if self.turns and end - self.turns[-1].end < self.turn_gap:
            best = min(self.profiles, key=lambda p: self._dist(p, energy, pace)) if self.profiles else None
            if best and self._dist(best, energy, pace) < self.new_speaker_distance:
                speaker = self.turns[-1].speaker
                merged = True
                last = self.turns[-1]
                last.text += " " + text
                last.end = max(last.end, end)
                last.energy = (last.energy + energy) / 2
                last.pace = (last.pace + pace) / 2
                self._update(best, energy, pace)
        if not merged:
            if self.profiles:
                best = min(self.profiles, key=lambda p: self._dist(p, energy, pace))
                if self._dist(best, energy, pace) < self.new_speaker_distance:
                    speaker = best["id"]
                    self._update(best, energy, pace)
                else:
                    speaker = None
            if speaker is None:
                speaker = self._next_speaker
                self._next_speaker += 1
                self.profiles.append(dict(id=speaker, meanEnergy=energy, meanPace=pace, turnCount=1))
            self.turns.append(Turn(self._next_turn, text, start, end, energy, pace, speaker))
            self._next_turn += 1
        return speaker

    def _update(self, p, energy, pace):
        n = p["turnCount"] + 1
        p["meanEnergy"] = (p["meanEnergy"] * p["turnCount"] + energy) / n
        p["meanPace"] = (p["meanPace"] * p["turnCount"] + pace) / n
        p["turnCount"] += 1

# ---------- TodoExtractor (port) ----------

COMMIT_VERBS = {
    "hablar","enviar","mandar","preparar","revisar","llamar","escribir","crear","hacer",
    "terminar","acabar","enviaré","mandaré","haré","revisaré","prepararé","crearé","terminaré",
    "quedo","quedamos","encargo","encargamos","apunto","apuntamos","gestiono","gestionamos",
    "encargado","encargada","pendiente",
    "send","review","prepare","call","write","create","make","finish","do",
    "share","follow","check","draft","schedule","book","update","fix","ship",
}

MARKERS = [
    "tengo que","hay que","tenemos que","deberíamos","debo","me encargo","te encargas",
    "action item","to-do","todo:","pendiente","no olvides","acordamos","quedamos en",
    "i'll","i will","we should","we need to","let's","can you","could you","please",
    "necesitamos","quedamos","proponer",
]

DUE_KEYWORDS = [
    ("hoy",0),("today",0),("mañana",1),("tomorrow",1),("pasado mañana",2),
    ("esta semana",7),("this week",7),("próxima semana",14),("next week",14),
    ("este mes",30),("this month",30),
]

def sentences_of(text):
    out = []
    for part in text.replace("!", ".").replace("?", ".").replace("\n", ".").split("."):
        p = part.strip()
        if p: out.append(p)
    return out

def due_date(lower):
    for kw, days in DUE_KEYWORDS:
        if kw in lower:
            return days
    return None

def extract_one(sentence, speaker):
    lower = sentence.lower()
    has_marker = any(m in lower for m in MARKERS)
    if not has_marker:
        return None
    strong = has_marker and ("tengo que" in lower or "i'll" in lower)
    if not strong:
        return None
    text = sentence.strip()
    return dict(text=text, speaker=speaker, due=due_date(lower))

def extract_todos(turns):
    todos, seen = [], set()
    for t in turns:
        for s in sentences_of(t.text):
            todo = extract_one(s, t.speaker)
            if todo and todo["text"].lower() not in seen:
                seen.add(todo["text"].lower())
                todos.append(todo)
    return todos

# ---------- LocalSummarizer highlights (port) ----------

def highlights(turns):
    scored = []
    for t in turns:
        for s in sentences_of(t.text):
            l = s.lower()
            score = 0.0
            if any(k in l for k in ("tengo que","i'll","hay que","acordamos","quedamos")):
                score += 2
            if any(k in l for k in ("decidimos","conclusión","decided","conclusion")):
                score += 1.5
            wc = len(s.split())
            if 6 <= wc <= 25: score += 1
            if wc > 35: score -= 1
            if score > 1.5:
                scored.append((s, score))
    top = set(s for s, _ in sorted(scored, key=lambda x: -x[1])[:5])
    return [s for s, _ in scored if s in top]

# ---------- Tests ----------

class TestBlobatar(unittest.TestCase):
    def test_deterministic(self):
        for name in ["Blob", "Hablante 1", "Hablante 2", "Hablante 3", "ana", "alain00"]:
            self.assertEqual(blobatar_traits(name), blobatar_traits(name))

    def test_different_names_differ(self):
        a, b = blobatar_traits("Hablante 1"), blobatar_traits("Hablante 2")
        self.assertNotEqual((a["silhouette"], a["hue"]), (b["silhouette"], b["hue"]))

    def test_traits_in_range(self):
        for name in ["x", "y", "z", "Hablante 9"]:
            t = blobatar_traits(name)
            self.assertIn(t["silhouette"], range(10))
            self.assertIn(t["eye"], range(4))
            self.assertLessEqual(t["hue"], 1.0)
            self.assertTrue(-1 <= t["mouth"] <= 1)

class TestSegmenter(unittest.TestCase):
    def test_two_speakers_separated(self):
        seg = SpeakerSegmenter()
        seg.add_chunk(0, 10, "Hola, os presento el plan del trimestre.", 0.5, 2.2)
        seg.add_chunk(25, 35, "Gracias. Yo tengo que revisar el presupuesto.", 0.2, 1.1)
        speakers = {t.speaker for t in seg.turns}
        self.assertEqual(len(speakers), 2)

    def test_same_speaker_continues(self):
        seg = SpeakerSegmenter()
        seg.add_chunk(0, 10, "Hola, os presento el plan.", 0.5, 2.2)
        seg.add_chunk(11, 20, "Tengo que revisar el presupuesto.", 0.52, 2.3)
        speakers = {t.speaker for t in seg.turns}
        self.assertEqual(len(speakers), 1)

class TestTodos(unittest.TestCase):
    def test_extracts_spanish_todo(self):
        turns = [Turn(0, "Tengo que enviar el informe mañana.", 0, 5, 0.5, 2.0, 0)]
        todos = extract_todos(turns)
        self.assertEqual(len(todos), 1)
        self.assertEqual(todos[0]["due"], 1)
        self.assertEqual(todos[0]["speaker"], 0)

    def test_extracts_english_todo(self):
        turns = [Turn(0, "I'll send the report tomorrow.", 0, 5, 0.5, 2.0, 1)]
        todos = extract_todos(turns)
        self.assertEqual(len(todos), 1)
        self.assertEqual(todos[0]["due"], 1)

    def test_ignores_non_commitments(self):
        turns = [Turn(0, "El informe está listo y es muy bonito.", 0, 5, 0.5, 2.0, 0)]
        self.assertEqual(extract_todos(turns), [])

    def test_dedupes(self):
        turns = [Turn(0, "Tengo que enviar el informe. Tengo que enviar el informe.", 0, 5, 0.5, 2.0, 0)]
        self.assertEqual(len(extract_todos(turns)), 1)

class TestHighlights(unittest.TestCase):
    def test_picks_commitments(self):
        turns = [Turn(0, "Tengo que enviar el informe mañana. El café estaba bueno hoy.", 0, 5, 0.5, 2.0, 0)]
        h = highlights(turns)
        self.assertEqual(h, ["Tengo que enviar el informe mañana"])

if __name__ == "__main__":
    unittest.main(verbosity=2)
