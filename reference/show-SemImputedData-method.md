# Show SemImputedData

Method to display a concise summary of a SemImputedData object. This
method is automatically called when you print a SemImputedData object.

## Usage

``` r
# S4 method for class 'SemImputedData'
show(object)
```

## Arguments

- object:

  The SemImputedData object to be displayed.

## Value

This method does not return a value but displays a summary of the
SemImputedData object.

## Examples

``` r
if (FALSE) { # \dontrun{
data("HolzingerSwineford1939", package = "lavaan")
hs_data <- HolzingerSwineford1939[paste0("x", 1:9)] |> mice::ampute()
hs_data <- hs_data$amp
imp_data <- mice::mice(HolzingerSwineford1939, m = 5)
model_lav <- "visual  =~ x1 + x2 + x3
             textual =~ x4 + x5 + x6
             speed   =~ x7 + x8 + x9"
imp_data <- mice::mice(hs_data, m = 5)
sem_data <- SemImputedData(imp_data, model_lav)
show(sem_data)
} # }
```
