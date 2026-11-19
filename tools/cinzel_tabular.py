"""Add optional equal-advance figures to the game's static Cinzel Bold subset."""

from copy import deepcopy
from pathlib import Path
import sys

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.ttLib import TTFont


def add_tabular_figures(path: Path) -> None:
    with TTFont(path, recalcTimestamp=False) as font:
        glyphs = font["glyf"]
        metrics = font["hmtx"].metrics
        digits = [font.getBestCmap()[ord(char)] for char in "0123456789"]
        width = max(metrics[name][0] for name in digits)
        substitutions = []
        order = font.getGlyphOrder().copy()
        for name in digits:
            alternate = f"{name}.tnum"
            glyph = deepcopy(glyphs[name])
            advance, bearing = metrics[name]
            shift = round((width - advance) / 2)
            glyph.coordinates.translate((shift, 0))
            glyphs[alternate] = glyph
            metrics[alternate] = (width, bearing + shift)
            order.append(alternate)
            substitutions.append(f"sub {name} by {alternate};")
        font.setGlyphOrder(order)
        # The source subset has no GSUB features. Preserve its existing kerning table.
        if "GSUB" in font and font["GSUB"].table.FeatureList.FeatureRecord:
            raise ValueError("Expected the freshly subset Cinzel font with no substitution features")
        feature = "feature tnum { " + " ".join(substitutions) + " } tnum;"
        addOpenTypeFeaturesFromString(font, feature, tables=["GSUB"])
        font.save(path)


if __name__ == "__main__":
    add_tabular_figures(Path(sys.argv[1]))
