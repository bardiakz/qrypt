#!/usr/bin/env python3
"""
Generates and validates the v2 obfuscation maps for Qrypt (stdlib only).

A v2 map has exactly 17 entries: the 16 hex digits plus ':' (the AES
`ciphertext:iv` separator). Payloads, tag included, only ever contain those 17
characters, so a strict codec over them covers every message.

Commands (run from the project root):

  python tool/v2_maps.py generate [--force]
      Writes the STANDARD maps (fixed seeds) to
        lib/resources/obfuscation/built_in_v2_maps.dart
        test/fixtures/v2_maps.lock.json
      Refuses to overwrite either file without --force. Changing a shipped map
      makes every message produced with it undecodable. The lock file is
      compared against the Dart maps by a test, so an accidental change fails CI.

  python tool/v2_maps.py custom --pool fa-words [--seed "my secret"] [--format json|dart]
      Makes a map from any pool. With --seed it is deterministic; without, random.
      Pools: latin persian cyrillic greek hebrew armenian georgian hiragana
      (one character per symbol) and en-words fa-words (one word per symbol).
      The four standard styles (en1 en2 fa1 fa2) are also accepted.

  python tool/v2_maps.py pools [--force]
      Writes lib/resources/obfuscation/v2_map_pools.dart (the vetted pools the
      in-app generator draws from) and test/fixtures/v2_generator_vectors.json
      (expected output of the Dart generator, to prove it matches this script).

  python tool/v2_maps.py validate map.json --style fa2   (or any pool name)
      Checks a hand-written map (JSON object of 17 entries) against every rule.

Styles: en1 (Latin letters), en2 (English words), fa1 (Persian letters),
fa2 (Persian words).

Rules enforced on every map (the generator cannot emit a map that breaks them):
  * exactly the 17 keys; bijective (no two keys share a value)
  * no whitespace; already lowercase/casefolded (decoding is case-insensitive)
  * every character is a letter (Unicode category L*) and unchanged under
    NFC/NFD/NFKC/NFKD, so no combining marks, no zero-width/format characters,
    and nothing a clipboard or messenger's Unicode normalisation can rewrite
  * Persian: only letters from an allow-list that excludes Arabic look-alikes
    (ي ك) which Persian keyboards and apps silently convert, plus hamza/madda
    forms that decompose under NFD
  * char styles: exactly one code point per value, no value equal to its key
  * word styles: PREFIX-FREE. If one word were a prefix of another, the tag
    startsWith() match could misidentify messages (the legacy FA2 map had
    'چه' vs 'چهار').

Selection algorithm (so it can be ported and reproduced): the pool is
Fisher-Yates shuffled using SHA-256(f"{seed}:{counter}") as the random stream
(4-byte big-endian words, rejection sampling), then candidates are taken in
order, skipping any that violate a rule, until 17 are chosen. The i-th chosen
value is assigned to SYMBOLS[i].
"""
import argparse
import hashlib
import json
import sys
import unicodedata
from pathlib import Path

SYMBOLS = list("0123456789abcdef") + [":"]

# Persian base letters that are normalisation-stable and not subject to the
# common Arabic->Persian conversions.
FA_LETTERS = "ابپتثجچحخدذرزژسشصضطظعغفقکگلمنوهی"

EN_WORDS = (
    "apple bottle camera device energy forest garden house island jungle "
    "kitchen library machine nature office planet quality river silver table "
    "window yellow anchor bridge candle desert engine flower guitar harbor "
    "jacket ladder marble orange pencil rocket saddle tunnel violet wallet "
    "zipper basket cotton dragon falcon"
).split()

FA_WORDS = (
    "سلام خوب امروز باران دوست کتاب مدرسه خانه زمان ماه سال روز شب صبح عصر "
    "کار مردم شهر کشور جهان زندگی عشق خانواده بله خیر چرا چگونه کجا بود رفت "
    "گفت شنید دید خورد نوشید خوابید بیدار زیبا بزرگ کوچک تازه قدیمی"
).split()

STYLES = {
    "en1": dict(kind="char", pool=list("abcdefghijklmnopqrstuvwxyz"),
                alphabet="abcdefghijklmnopqrstuvwxyz",
                enum="en1v2", const="builtInEn1V2Map"),
    "en2": dict(kind="word", pool=EN_WORDS,
                alphabet="abcdefghijklmnopqrstuvwxyz",
                enum="en2v2", const="builtInEn2V2Map"),
    "fa1": dict(kind="char", pool=list(FA_LETTERS), alphabet=FA_LETTERS,
                enum="fa1v2", const="builtInFa1V2Map"),
    "fa2": dict(kind="word", pool=FA_WORDS, alphabet=FA_LETTERS,
                enum="fa2v2", const="builtInFa2V2Map"),
}

STANDARD_SEED = "qrypt-v2/{style}"  # fixed forever; see header


def _cfg(name):
    return STYLES[name] if name in STYLES else POOLS[name]



# ------------------------------------------------------- large runtime pools
# These feed the in-app random map generator (see `pools` command). The
# STANDARD maps above use the small frozen pools; do not touch those.
POOLS_VERSION = 1


def _unicode_letters(ranges):
    """Lowercase letters that survive every normalisation unchanged."""
    out = []
    for lo, hi in ranges:
        for cp in range(lo, hi + 1):
            c = chr(cp)
            if unicodedata.category(c) not in ("Ll", "Lo"):
                continue
            if any(unicodedata.normalize(f, c) != c
                   for f in ("NFC", "NFD", "NFKC", "NFKD")):
                continue
            if c != c.lower() or c != c.casefold():
                continue
            out.append(c)
    return out


EN_WORDS_BIG = sorted(set("""
acorn alder amber aspen autumn badger bamboo beach beaver birch blossom boulder
breeze brook cactus canyon cedar cherry chestnut clover coast coral cove creek
crystal cypress daisy dawn delta dune eagle ember fern field fjord forest fossil
frost glacier glade granite grove harbor hazel heron hill horizon iceberg island
ivory jasmine juniper lagoon lake larch lava leaf lemon lichen lilac lily lotus
maple meadow mist moss mountain oasis ocean olive orchid otter pebble pine pond
poppy prairie quartz rainbow raven reef ridge river saffron sage sapphire
sequoia shadow shore sparrow spruce stream summit sunrise swan thistle thunder
timber tulip valley velvet violet walnut waterfall willow winter zephyr
anchor basket blanket bottle bridge bucket button cabinet candle canvas carpet
castle chair clock compass copper cradle curtain drawer easel engine feather
fiddle flute fountain furnace gadget garage goblet hammer helmet hinge jacket
jewel kettle ladder lantern locket magnet mantle marble mirror needle notebook
paddle palace pencil pillow pitcher pocket puzzle quiver radio ribbon rocket
saddle satchel scarf shelter shovel skillet spindle spoon statue stool teapot
thimble ticket tunnel turret umbrella vessel violin wagon wallet whistle window
wrench zipper
almond apricot banana barley biscuit butter cashew celery cinnamon coconut
cookie cucumber custard garlic ginger honey lentil mango muffin mustard noodle
nutmeg oatmeal onion orange papaya parsley peach pepper pickle plum pumpkin
radish raisin spinach sugar tomato truffle vanilla waffle
alpaca beetle bison camel canary cheetah cricket dolphin donkey falcon ferret
firefly gazelle gecko giraffe gopher hamster hedgehog jaguar kitten koala
lizard llama lobster magpie meerkat monkey ostrich panda parrot pelican
penguin rabbit salmon seagull turtle walrus weasel zebra
apple camera device energy house jungle kitchen library machine nature office
planet quality robot system table yard
""".split()))

FA_WORDS_BIG = sorted(set("""
کوه دریا جنگل دشت باغ گل درخت برگ ابر باد برف باران خورشید ستاره زمین سنگ خاک
ماسه موج ساحل جزیره غار چشمه دره تپه کویر شاخه ریشه میوه سیب انار انگور هلو
گیلاس توت پسته بادام گردو نخل چنار سرو بید لاله نرگس یاس سوسن بنفشه مرداب
تالاب اسب شیر گرگ روباه خرس عقاب کبوتر گنجشک ماهی پلنگ خرگوش شتر گوسفند گاو
مرغ خروس پروانه زنبور مورچه طوطی بلبل شاهین کلاغ جوجه قناری دلفین کوسه
میز صندلی پنجره چراغ کلید قفل قلم دفتر ساعت فرش پرده بشقاب قاشق چنگال لیوان
کتری سبد طناب چکش نردبان چتر کفش کلاه عینک کیف دوچرخه قایق کشتی قطار
هواپیما ماشین برج قلعه مسجد بازار میدان خیابان کوچه جاده تونل دیوار سقف
سرخ سبز زرد سفید سیاه نارنجی بنفش صورتی خاکستری
برنج عسل پنیر ماست کره شکر نمک چای قهوه خرما زیتون سیر پیاز سبزی هویج کلم
کدو بادمجان گوجه خیار فلفل زعفران دارچین لیمو پرتقال نارنگی هندوانه خربزه
انجیر کباب شیرینی
بهار تابستان پاییز زمستان سپیده غروب بامداد شامگاه
گنج کمان پرنده پرواز دانه ریسمان نقشه تصویر موسیقی ترانه سرود نغمه رقص
سلام خوب امروز دوست کتاب مدرسه خانه زمان ماه سال روز شب صبح عصر کار مردم
شهر کشور جهان زندگی عشق خانواده بله خیر چرا چگونه کجا بود رفت گفت شنید دید
خورد نوشید خوابید بیدار زیبا بزرگ کوچک تازه قدیمی
""".split()))

POOLS = {
    "latin": dict(kind="char", pool=list("abcdefghijklmnopqrstuvwxyz")),
    "persian": dict(kind="char", pool=list(FA_LETTERS)),
    "cyrillic": dict(kind="char", pool=_unicode_letters([(0x0430, 0x045F)])),
    "greek": dict(kind="char", pool=_unicode_letters([(0x03B1, 0x03C9)])),
    "hebrew": dict(kind="char", pool=_unicode_letters([(0x05D0, 0x05EA)])),
    "armenian": dict(kind="char", pool=_unicode_letters([(0x0561, 0x0586)])),
    "georgian": dict(kind="char", pool=_unicode_letters([(0x10D0, 0x10F0)])),
    "hiragana": dict(kind="char", pool=_unicode_letters([(0x3041, 0x3093)])),
    "en-words": dict(kind="word", pool=EN_WORDS_BIG),
    "fa-words": dict(kind="word", pool=FA_WORDS_BIG),
}
for _name, _c in POOLS.items():
    if _c["kind"] == "char":
        _c["alphabet"] = "".join(_c["pool"])
    else:
        _c["alphabet"] = ("abcdefghijklmnopqrstuvwxyz" if _name == "en-words"
                          else FA_LETTERS)


# ---------------------------------------------------------------- randomness
def _stream(seed):
    counter = 0
    while True:
        digest = hashlib.sha256(f"{seed}:{counter}".encode()).digest()
        for i in range(0, 32, 4):
            yield int.from_bytes(digest[i:i + 4], "big")
        counter += 1


def _randbelow(stream, n):
    limit = 2 ** 32 - (2 ** 32 % n)
    while True:
        v = next(stream)
        if v < limit:
            return v % n


def _shuffled(pool, seed):
    a = list(pool)
    s = _stream(seed)
    for i in range(len(a) - 1, 0, -1):
        j = _randbelow(s, i + 1)
        a[i], a[j] = a[j], a[i]
    return a


# ---------------------------------------------------------------- validation
def _check_value(v, style):
    cfg = _cfg(style)
    errs = []
    if not isinstance(v, str) or not v:
        return ["empty or non-string value"]
    if any(c.isspace() for c in v):
        errs.append("contains whitespace")
    if v != v.lower() or v != v.casefold():
        errs.append("not lowercase/casefolded")
    for form in ("NFC", "NFD", "NFKC", "NFKD"):
        if unicodedata.normalize(form, v) != v:
            errs.append(f"changes under {form} normalisation")
    for c in v:
        if not unicodedata.category(c).startswith("L"):
            errs.append(f"U+{ord(c):04X} is not a letter "
                        f"({unicodedata.category(c)})")
        if c not in cfg["alphabet"]:
            errs.append(f"U+{ord(c):04X} is outside this style's allowed alphabet")
    if cfg["kind"] == "char" and len(v) != 1:
        errs.append("must be exactly one code point")
    return errs


def validate(m, style):
    cfg = _cfg(style)
    errs = []
    if set(m.keys()) != set(SYMBOLS):
        missing = [k for k in SYMBOLS if k not in m]
        extra = [k for k in m if k not in SYMBOLS]
        errs.append(f"keys must be exactly the 17 symbols; missing={missing} "
                    f"extra={extra}")
        return errs
    seen = {}
    for k in SYMBOLS:
        v = m[k]
        for e in _check_value(v, style):
            errs.append(f"'{k}' -> '{v}': {e}")
        if v in seen:
            errs.append(f"collision: '{seen[v]}' and '{k}' both map to '{v}'")
        seen[v] = k
        if cfg["kind"] == "char" and v == k:
            errs.append(f"'{k}' maps to itself")
    if cfg["kind"] == "word":
        for a in SYMBOLS:
            for b in SYMBOLS:
                if a != b and m[b].startswith(m[a]):
                    errs.append(f"not prefix-free: '{m[a]}' ({a}) is a prefix "
                                f"of '{m[b]}' ({b})")
    if not errs:
        errs += _roundtrip(m, style)
    return errs


def _roundtrip(m, style):
    """Simulates the Dart codecs: encode, normalise like the decoder, decode."""
    word = _cfg(style)["kind"] == "word"
    rev = {v: k for k, v in m.items()}
    text = "deadbeef0123456789abcdef:0123456789abcdef" * 3
    enc = (" " if word else "").join(m[c] for c in text)
    # prefix property for tag stripping (tag = first 6 symbols)
    tag = (" " if word else "").join(m[c] for c in text[:6])
    if not enc.startswith(tag):
        return ["tag is not a prefix of the encoded message"]
    rest = enc[len(tag):]
    if word:
        toks = rest.strip().split()
        dec = "".join(rev[t] for t in toks)
    else:
        dec = "".join(rev[c] for c in rest)
    if dec != text[6:]:
        return ["round trip failed"]
    return []


# ---------------------------------------------------------------- generation
def generate_map(style, seed):
    cfg = _cfg(style)
    chosen = []
    for cand in _shuffled(cfg["pool"], seed):
        pos = len(chosen)
        if cfg["kind"] == "char" and cand == SYMBOLS[pos]:
            continue  # no fixed points
        if cfg["kind"] == "word" and any(
            cand.startswith(c) or c.startswith(cand) for c in chosen
        ):
            continue  # keep the set prefix-free
        if _check_value(cand, style):
            continue
        chosen.append(cand)
        if len(chosen) == 17:
            break
    if len(chosen) < 17:
        sys.exit(f"pool for {style} cannot supply 17 valid entries")
    m = dict(zip(SYMBOLS, chosen))
    errs = validate(m, style)
    if errs:
        sys.exit("internal error, generated map is invalid:\n" + "\n".join(errs))
    return m


# ---------------------------------------------------------------- rendering
def _dart_literal(v):
    if all(ord(c) < 128 for c in v):
        return f"'{v}'"
    return "'" + "".join(f"\\u{ord(c):04x}" for c in v) + "'"


def render_dart_map(const, m, with_comments=True):
    lines = [f"const Map<String, String> {const} = {{"]
    for k in SYMBOLS:
        v = m[k]
        note = f"  // {v}" if with_comments and any(ord(c) > 127 for c in v) else ""
        lines.append(f"  '{k}': {_dart_literal(v)},{note}")
    lines.append("};")
    return "\n".join(lines)


def render_dart_file(maps):
    out = [
        "// GENERATED by tool/v2_maps.py. DO NOT EDIT BY HAND.",
        "//",
        "// Standard v2 obfuscation maps: 16 hex digits plus ':' (AES separator).",
        "// These are a WIRE FORMAT. Changing any entry makes every message ever",
        "// produced with that method undecodable. A test compares these maps with",
        "// test/fixtures/v2_maps.lock.json to catch accidental changes.",
        "",
        "import 'package:qrypt/models/obfuscation_method.dart';",
        "",
    ]
    for style in ("en1", "en2", "fa1", "fa2"):
        out.append(render_dart_map(STYLES[style]["const"], maps[style]))
        out.append("")
    out += [
        "Map<String, String> builtInV2MapForMethod(ObfuscationMethod method) {",
        "  switch (method) {",
    ]
    for style in ("en1", "en2", "fa1", "fa2"):
        c = STYLES[style]
        out.append(f"    case ObfuscationMethod.{c['enum']}:")
        out.append(f"      return Map<String, String>.from({c['const']});")
    out += ["    default:", "      return <String, String>{};", "  }", "}", ""]
    return "\n".join(out)


# ---------------------------------------------------------------- commands
def cmd_generate(args):
    dart_path = Path(args.out)
    lock_path = Path(args.lock)
    for p in (dart_path, lock_path):
        if p.exists() and not args.force:
            sys.exit(f"{p} already exists. Shipped v2 maps must not change "
                     f"(it breaks existing messages). Use --force only "
                     f"before the first release.")
    maps = {s: generate_map(s, STANDARD_SEED.format(style=s)) for s in STYLES}
    dart_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    dart_path.write_text(render_dart_file(maps), encoding="utf-8")
    lock = {STYLES[s]["enum"]: maps[s] for s in STYLES}
    lock_path.write_text(
        json.dumps({"version": 1, "maps": lock}, ensure_ascii=False, indent=1)
        + "\n", encoding="utf-8")
    print(f"wrote {dart_path}\nwrote {lock_path}")



VECTOR_SEED = "qrypt-generator-vector-1"


def _wrap_items(items, indent="    ", width=78):
    lines, cur = [], indent
    for it in items:
        tok = _dart_literal(it) + ", "
        if len(cur) + len(tok) > width and cur.strip():
            lines.append(cur.rstrip())
            cur = indent
        cur += tok
    lines.append(cur.rstrip())
    return "\n".join(lines)


def render_pools_dart():
    out = [
        "// GENERATED by tool/v2_maps.py (command: pools). DO NOT EDIT BY HAND.",
        "//",
        "// Vetted pools for the random v2 map generator. Every character is a",
        "// letter that is unchanged under NFC/NFD/NFKC/NFKD and lowercase-stable;",
        "// every word is built only from those letters. The runtime validator",
        "// (ObfuscationService.validateV2Map) also accepts ONLY these characters,",
        "// since Dart has no Unicode normalisation to check with.",
        "//",
        "// Contents AND ORDER are frozen for a given kV2PoolsVersion: seeded",
        "// generation (passphrase -> map) depends on them. To add characters or",
        "// words, bump the version and add to a NEW pool; never reorder or",
        "// remove. test/fixtures/v2_generator_vectors.json guards this.",
        "",
        f"const int kV2PoolsVersion = {POOLS_VERSION};",
        "",
    ]
    for kind, const in (("char", "kV2CharPools"), ("word", "kV2WordPools")):
        out.append(f"const Map<String, List<String>> {const} = {{")
        for name, c in POOLS.items():
            if c["kind"] != kind:
                continue
            out.append(f"  // {name}: {len(c['pool'])} entries")
            out.append(f"  '{name}': [")
            out.append(_wrap_items(c["pool"]))
            out.append("  ],")
        out.append("};")
        out.append("")
    return "\n".join(out)


def cmd_pools(args):
    dart_path, vec_path = Path(args.out), Path(args.vectors)
    for p in (dart_path, vec_path):
        if p.exists() and not args.force:
            sys.exit(f"{p} already exists. Pools are frozen per version; bump "
                     f"POOLS_VERSION and add NEW pools instead, or --force "
                     f"before the first release.")
    for name, c in POOLS.items():
        assert len(c["pool"]) == len(set(c["pool"])), f"duplicates in {name}"
        for it in c["pool"]:
            assert not _check_value(it, name), (name, it)
            assert all(ord(ch) < 0x10000 for ch in it), "non-BMP in " + name
    # The frozen standard maps must stay inside the vetted alphabets.
    union = set("".join(c["alphabet"] for c in POOLS.values()))
    lock = json.loads(Path("test/fixtures/v2_maps.lock.json").read_text("utf-8"))
    for enum, m in lock["maps"].items():
        for v in m.values():
            assert set(v) <= union, (enum, v)
    st = _stream("abc")
    vec = {
        "poolsVersion": POOLS_VERSION,
        "seed": VECTOR_SEED,
        "maps": {n: generate_map(n, VECTOR_SEED) for n in POOLS},
        "nextInt": {
            "seed": "abc",
            "calls": [[m, _randbelow(st, m)] for m in
                      (1000, 17, 17, 40, 282, 220, 2, 3, 1000, 26)],
        },
    }
    dart_path.parent.mkdir(parents=True, exist_ok=True)
    vec_path.parent.mkdir(parents=True, exist_ok=True)
    dart_path.write_text(render_pools_dart(), encoding="utf-8")
    vec_path.write_text(json.dumps(vec, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8")
    print(f"wrote {dart_path}\nwrote {vec_path}")
    for n, c in POOLS.items():
        print(f"  {n:9} {c['kind']:4} {len(c['pool'])}")


def cmd_custom(args):
    seed = args.seed
    if seed is None:
        import secrets
        seed = secrets.token_hex(16)
        print(f"# seed: {seed}  (pass --seed to reproduce)", file=sys.stderr)
    m = generate_map(args.pool, seed)
    if args.format == "json":
        print(json.dumps(m, ensure_ascii=False, indent=1))
    else:
        print(render_dart_map("customV2Map", m))


def cmd_validate(args):
    m = json.loads(Path(args.file).read_text(encoding="utf-8"))
    errs = validate(m, args.style)
    if errs:
        print("INVALID:\n  - " + "\n  - ".join(errs))
        sys.exit(1)
    print("OK")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate")
    g.add_argument("--out", default="lib/resources/obfuscation/built_in_v2_maps.dart")
    g.add_argument("--lock", default="test/fixtures/v2_maps.lock.json")
    g.add_argument("--force", action="store_true")
    g.set_defaults(fn=cmd_generate)

    all_pools = list(STYLES) + list(POOLS)

    c = sub.add_parser("custom", help="random/seeded map from any pool")
    c.add_argument("--pool", choices=all_pools, required=True)
    c.add_argument("--seed", help="omit for a fresh random map")
    c.add_argument("--format", choices=("json", "dart"), default="json")
    c.set_defaults(fn=cmd_custom)

    pl = sub.add_parser("pools", help="write the runtime pools + test vectors")
    pl.add_argument("--out", default="lib/resources/obfuscation/v2_map_pools.dart")
    pl.add_argument("--vectors", default="test/fixtures/v2_generator_vectors.json")
    pl.add_argument("--force", action="store_true")
    pl.set_defaults(fn=cmd_pools)

    v = sub.add_parser("validate")
    v.add_argument("file")
    v.add_argument("--style", choices=all_pools, required=True)
    v.set_defaults(fn=cmd_validate)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
