#' Pass data to Powerpoint workbooks
#'
#' \code{to_ppt} allows you to pass R objects to an open \code{pptWorkbook},
#' and write it later with \code{write_data}. The \code{pptWorkbook} can be created
#' by calling \code{ppt_workbook}. \code{to_ppt} will always format
#' the output and add it to a new slide.
#'
#' You can use this function to pass \code{plot}, \code{data.frame} (\code{table} and
#' \code{matrix} will be coerced), and \code{character} objects to the workbook.
#' Strings are assumed to be markdown.
#'
#' @param x A \code{data.frame}, \code{string} or \code{plot}
#' @param wb A \code{pptWorkbook}.
#' @param title Title to use for the new slide. Defaults to a single whitespace when
#' title is \code{NULL}.
#' @param subtitle The subtitle for the slide. When \code{NULL} (the default),
#' \code{to_ppt} will use the 'title' attribute of the object, or a single whitespace
#' if \code{attr(x, 'title')} returns \code{NULL} as well.
#' @param template Optional: Specify a path if you would like to append slides to
#' an existing powerpoint file (use it as a template). Default uses the template
#' included in this package.
#' @param font Default font (Replaces the \code{ReporteRs-default-font} option).
#' @param fontsize Default fontsize (Replaces the \code{ReporteRs-fontsize} option).
#' @author Kristian D. Olsen
#' @note This function requires \pkg{ReporteRs}. The \code{pptWorkbook} object
#' is a thin R6 wrapper around ReporteR's \code{pptx}, and allow us to use
#' \code{to_ppt} in chained expressions, since the workbook is mutable.
#' @export
#' @examples
#' if (require(ReporteRs)) {
#'  wb <- ppt_workbook()
#'  df <- data.frame("String" = c("A", "B"), "Int" = c(1:2L), "Percent" = c(0.5, 0.75))
#'
#'  # The workbook is mutable, so we don't have to assign result.
#'  to_ppt(df, wb, title = "Example data", subtitle = "")
#'
#'  # Data is first argument, so we can use it with dplyr.
#'  # df %>% to_ppt(wb, title = "Example data", subtitle = "")
#'
#'  # Save the data
#'  write_data(wb, "Example table.pptx")
#' }

to_ppt <- function(x, wb, title = NULL, subtitle = NULL) {
  if (!requireNamespace("ReporteRs")) {
    stop("This function requires 'ReporteRs'.")
  } else if (!inherits(wb, "pptWorkbook")) {
    stop ("'wb' should be a pptWorkbook. See help(to_ppt).")
  }
  UseMethod("to_ppt")
}

#' @rdname to_ppt
#' @export
ppt_workbook <- function(template = NULL, font = "Calibri", fontsize = 10L) {
  # Set ReporteRs options.
  options("ReporteRs-default-font" = font)
  options("ReporteRs-fontsize" = fontsize)

  pptWorkbook$new(template)
}

#' @export
write_data.pptWorkbook <- function(x, file, ...) {
  if (!requireNamespace("ReporteRs")) {
    stop("'ReporteRs' required to write pptWorkbook.")
  }
  ReporteRs::writeDoc(x$obj, file = file, ...)
}

#' @rdname to_ppt
#' @export
to_ppt.data.frame <- function(x, wb, title = NULL, subtitle = NULL) {
  subtitle <- subtitle %||% attr(x, "title")
  wb$add_table(format_flextable(x), title %||% " ", subtitle %||% " ")
}

#' @export
to_ppt.data.table <- function(x, wb, title = NULL, subtitle = NULL) {
  warning("Coercing ", class(x), " to data.frame.")
  subtitle <- subtitle %||% attr(x, "title")
  to_ppt(as.data.frame(x, stringsAsFactors = FALSE), wb, title, subtitle)
}

#' @rdname to_ppt
#' @export
to_ppt.FlexTable <- function(x, wb, title = NULL, subtitle = NULL) {
  subtitle <- subtitle %||% attr(x, "title")
  wb$add_table(x, title %||% " ", subtitle %||% " ")
}

#' @rdname to_ppt
#' @export
to_ppt.ggplot <- function(x, wb, title = NULL, subtitle = NULL) {
  subtitle <- subtitle %||% attr(x, "title")
  wb$add_plot(x, title %||% " ", subtitle %||% " ")
}

# Plots returned by evaluate::evaluate().
#' @export
to_ppt.recordedplot <- to_ppt.ggplot

#' @rdname to_ppt
#' @export
to_ppt.character <- function(x, wb, title = NULL, subtitle = NULL) {
  if (!is_string(x))
    stop("'to_ppt' only supports strings (length 1 character vector).")
  subtitle <- subtitle %||% attr(x, "title")
  wb$add_markdown(x, title %||% " ", subtitle %||% " ")
}

#' @export
to_ppt.table  <- to_ppt.data.table

#' @export
to_ppt.matrix <- to_ppt.data.table

#' Add a title slide
#'
#' Use \code{add_ts} to add a title slide to a \code{pptWorkbook}.
#'
#' @param wb A \code{pptWorkbook}.
#' @param type The type of report (blue text).
#' @param title Title for the report (red text).
#' @param author The first line after the title, usually author.
#' @param date Last line on the title slide. E.g. year.
#' @author Kristian D. Olsen
#' @seealso \code{\link{to_ppt}} for more information.
#' @export

add_ts <- function(wb, type = NULL, title = NULL, author = NULL, date = NULL) {
  wb$title_slide(type %||% " ",  title %||% " ", author %||% " ", date %||% " ")
}

# Workbook for powerpoint (R6 Class) -------------------------------------------
# This exists because ReporteRs does not use a mutable object for documents,
# and I want to_ppt/to_excel to have identical interfaces.
#' @importFrom R6 R6Class
pptWorkbook <- R6::R6Class("pptWorkbook",
  public = list(
    obj = NULL,

    initialize = function(template = NULL) {
      if (!requireNamespace("ReporteRs")) {
        stop("'ReporteRs' required to create a pptWorkbook.")
      }
      template <- template %||% system.file("ppt", "template.pptx", package = "seamless")
      self$obj <- ReporteRs::pptx(template = clean_path(template))
    },

    title_slide = function(type, title, author, date) {
      self$obj <- ReporteRs::addSlide(self$obj, slide.layout = "Title Slide")
      self$obj <- ReporteRs::addTitle(self$obj, type) # Blue text
      self$obj <- ReporteRs::addParagraph(self$obj, title) # Red text
      self$obj <- ReporteRs::addParagraph(self$obj, author)
      self$obj <- ReporteRs::addParagraph(self$obj, date)
      invisible(self)
    },

    add_table = function(x, title, subtitle) {
      self$obj <- ReporteRs::addSlide(self$obj, slide.layout = "Title and Content")
      self$obj <- ReporteRs::addTitle(self$obj, title)
      self$obj <- ReporteRs::addFlexTable(self$obj, x)
      self$obj <- ReporteRs::addParagraph(self$obj, subtitle)
      invisible(self)
    },

    add_plot = function(x, title, subtitle) {
      self$obj <- ReporteRs::addSlide(self$obj, slide.layout = 'Title and Content')
      self$obj <- ReporteRs::addTitle(self$obj, title)
      self$obj <- ReporteRs::addPlot(self$obj, fun = print, x = x, bg = "transparent")
      self$obj <- ReporteRs::addParagraph(self$obj, subtitle)
      invisible(self)
    },

    add_markdown = function(x, title, subtitle) {
      self$obj <- ReporteRs::addSlide(self$obj, slide.layout = 'Title and Content')
      self$obj <- ReporteRs::addTitle(self$obj, title)
      suppressWarnings( # Depreciated warning - covered in tests.
        self$obj <- ReporteRs::addMarkdown(self$obj, text = x)
        )
      self$obj <- ReporteRs::addParagraph(self$obj, subtitle)
      invisible(self)
    },

    print = function() {
      print(self$obj)
    }

  )
)

# Create a flextable with the correct theme ------------------------------------
format_flextable <- function(df) {
  is_percent <- vapply(df, is_percent, logical(1), USE.NAMES = FALSE)
  is_numeric <- vapply(df, is.numeric, logical(1), USE.NAMES = FALSE)

  # Format numeric and/or percent columns
  if (any(is_numeric)) {
    df[is_numeric & !is_percent] <- lapply(df[is_numeric & !is_percent], sprintf, fmt = "%.2f")
  }
  if (any(is_percent)) {
    df[is_percent] <- lapply(df[is_percent], function(v) sprintf(fmt = "%.0f %%", v*100))
  }

  # Create the flextable
  ft <- ReporteRs::FlexTable(
    data = df,
    header.columns = TRUE,
    add.rownames = FALSE,
    body.par.props = ReporteRs::parProperties(padding = 0L),
    body.cell.props = ppt_body_cell(),
    body.text.props = ppt_body_text(),
    header.par.props = ReporteRs::parProperties(padding = 0L),
    header.cell.props = ppt_header_cell(),
    header.text.props = ppt_header_text()
  )

  # Center numeric columns
  center <- ReporteRs::parProperties(text.align = "center")
  ft[, which(is_numeric)] <- center
  ft[, which(is_numeric), to = "header"] <- center

  # Color border for the last row
  ft[nrow(df), ] <- ppt_last_row()

  # Use columnnames to allocate width for each column.
  n_char <- nchar(names(df))
  n_char <- n_char/sum(n_char) * 9L
  ft <- ReporteRs::setFlexTableWidths(ft, n_char)

  # Return
  ft

}

# PPT theme --------------------------------------------------------------------
ppt_header_text <- function() {
  ReporteRs::textProperties(
    font.size = getOption("ReporteRs-fontsize"),
    font.family = getOption("ReporteRs-default-font"),
    font.weight = "bold"
  )
}

ppt_header_cell <- function() {
  ReporteRs::cellProperties(
    border.left.style = "none",
    border.right.style = "none",
    border.top.color = "#0094A5",
    border.top.style = "solid",
    border.top.width = 3L,
    border.bottom.color = "#0094A5",
    border.bottom.style = "solid",
    border.bottom.width = 1L,
    padding.top = 2L,
    padding.bottom = 1L,
    background.color = "#CCE9EB"
  )
}

# Body styles
ppt_body_text <- function() {
  ReporteRs::textProperties(
    font.size = getOption("ReporteRs-fontsize") - 2L,
    font.family = getOption("ReporteRs-default-font"),
    font.weight = "normal"
  )
}

ppt_body_cell <- function() {
  ReporteRs::cellProperties(
    border.left.style = "none",
    border.right.style = "none",
    border.top.style = "none",
    border.bottom.color = "#BFBFBF",
    border.bottom.style = "solid",
    border.bottom.width = 1L,
    padding.top = 1L,
    padding.bottom = 1L,
    background.color = "transparent"
  )
}

# Separate cell style for bottom row
ppt_last_row <- function() {
  ReporteRs::cellProperties(
    border.left.style = "none",
    border.right.style = "none",
    border.top.style = "none",
    border.bottom.color = "#0094A5",
    border.bottom.style = "solid",
    border.bottom.width = 2L,
    padding.top = 1L,
    padding.bottom = 1L,
    background.color = "transparent"
  )
}
