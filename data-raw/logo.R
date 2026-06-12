# data-raw/logo.R — generate man/figures/logo.png (ggplot2-only hex sticker).
# Motif: the mediation triangle X -> M -> Y with the direct path X -> Y dashed,
# evoking missing/incomplete information. Run: Rscript data-raw/logo.R
suppressPackageStartupMessages(library(ggplot2))

navy <- "#15314f"; sky <- "#7fb2e5"; ice <- "#dceafb"; white <- "#ffffff"

# Pointy-top hexagon, unit radius.
ang <- c(90, 150, 210, 270, 330, 30) * pi / 180
hex <- data.frame(x = cos(ang), y = sin(ang))

# Mediation nodes: X bottom-left, M top, Y bottom-right.
nodes <- data.frame(lab = c("X", "M", "Y"),
                    x = c(-0.46, 0, 0.46), y = c(-0.18, 0.40, -0.18))
# a-path (X->M) and b-path (M->Y): solid. Direct c' (X->Y): dashed = "missing".
solid <- data.frame(x = c(-0.46, 0), y = c(-0.18, 0.40),
                    xend = c(0, 0.46), yend = c(0.40, -0.18))
dash  <- data.frame(x = -0.46, y = -0.18, xend = 0.46, yend = -0.18)

p <- ggplot() +
  geom_polygon(data = hex, aes(x, y), fill = navy, colour = sky, linewidth = 2.2) +
  geom_segment(data = solid, aes(x, y, xend = xend, yend = yend), colour = ice,
               linewidth = 1.2, arrow = arrow(length = unit(0.05, "npc"), type = "closed")) +
  geom_segment(data = dash, aes(x, y, xend = xend, yend = yend), colour = sky,
               linewidth = 1.0, linetype = "22",
               arrow = arrow(length = unit(0.05, "npc"), type = "closed")) +
  geom_point(data = nodes, aes(x, y), size = 11, colour = ice) +
  geom_text(data = nodes, aes(x, y, label = lab), colour = navy,
            fontface = "bold", size = 5.2) +
  annotate("text", x = 0, y = -0.50, label = "missingmed", colour = white,
           fontface = "bold", size = 5.0) +
  coord_fixed(xlim = c(-1.05, 1.05), ylim = c(-1.12, 1.12)) +
  theme_void()

dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)
ggsave("man/figures/logo.png", p, width = 2.0, height = 2.3, dpi = 300, bg = "transparent")
cat("wrote man/figures/logo.png\n")
