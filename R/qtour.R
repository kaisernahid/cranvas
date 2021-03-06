#' Create a tour associated with a mutaframe
#'
#' The \pkg{tourr} package is used to create the tour projections. This function
#' creates an \R object to manipulate the tour, and all the changes in the tour
#' can be reflected immediately in plots created in \pkg{cranvas}.
#'
#' Because the data provided to the tour is a mutaframe, it can listen to
#' changes through listeners on it. Usually these listeners can update the plots
#' which are created from this mutaframe (further, those linked to this
#' mutaframe) on the fly.
#'
#' Four basic methods can be applied to the object returned by this function
#' (say, \code{tour}):
#'
#' \describe{ \item{\code{tour$start()}}{starts the tour (tour projections
#' change successively and are attached to the mutaframe; column names are
#' \code{tour_1}, \code{tour_2}, ...)} \item{\code{tour$stop()}}{pauses the
#' tour} \item{\code{tour$slower()}}{makes the tour slower}
#' \item{\code{tour$faster()}}{makes it faster.} }
#'
#' We can also modify the parameters passed to \code{\link{qtour}()} on the fly
#' through this object. For example, we can change the type of tour to the
#' guided tour using a syntax like \code{tour$tour_path <- guided_tour(...)}.
#' All other parameters can be changed similarly, including \code{vars},
#' \code{aps}, \code{fps}, \code{rescale} and \code{sphere}.
#' @param vars variable names to be used in the tour (parsed by
#'   \code{\link{var_names}})
#' @inheritParams qbar
#' @inheritParams tourr::animate
#' @return An object generated by reference classes with signals.
#' @author Yihui Xie <\url{http://yihui.name}>
#' @export
#' @example inst/examples/qtour-ex.R
qtour = function(vars = ~., data, tour_path, aps = 1, fps = 30, rescale = TRUE,
                 sphere = FALSE, ...) {
  library(tourr)
  if (missing(tour_path)) tour_path = grand_tour()
  data = check_data(data)
  src = last_time = tour = timer = NULL
  tour_step = function() {
    if (is.null(last_time)) {
      last_time <<- proc.time()[3]
      delta = 0
    } else {
      cur_time = proc.time()[3]
      delta = (cur_time - last_time)
      last_time <<- cur_time
    }
    step = tour(meta$aps * delta)
    if (is.null(step$proj)) {
      meta$pause()
      return()
    }
    data_proj = src %*% step$proj
    data_proj = scale(data_proj, center = TRUE, scale = FALSE)
    colnames(data_proj) = paste('proj', 1:ncol(data_proj), sep = '')
    for(col in colnames(data_proj)) {
      data[[col]] = data_proj[, col]
    }
    invisible(step)
  }
  timer = qtimer(1000, tour_step)
  src = vapply(as.data.frame(data[, vars]), as.numeric, numeric(nrow(data)))
  if (rescale) src = tourr::rescale(src)
  if (sphere) src = tourr::sphere(src)
  tour = new_tour(src, tour_path, NULL)
  timer$interval = 1000 / fps
  meta = Tour.meta$new(
    timer = timer,vars = var_names(vars, data), data = data, src = src,
    tour = tour, aps = new('NumericWithMin0Max3', aps), aps.init = aps,
    fps = new('NumericWithMin0Max60', fps), rescale = rescale, sphere = sphere,
    tour_path = tour_path
  )
  meta$regSignal()
  meta
}

setOldClass('tour_path')
setOldClass('QTimer')
setOldClass('mutaframe')

setRefClass(
  'QTour', contains = 'VIRTUAL',
  fields = list(
    timer = 'QTimer', last_time = 'numeric', vars = 'character',
    tour_path = 'tour_path', data = 'mutaframe', src = 'matrix', tour = 'function'
  )
)

speedcontrol = setNumericWithRange('Numeric', min=0, max=3)
fpscontrol = setNumericWithRange('Numeric', min=0, max=60)

Tour.meta = setRefClass(
  'Tourr_meta',
  fields = properties(list(
    aps = 'NumericWithMin0Max3',
    aps.init = 'numeric',
    fps = 'NumericWithMin0Max60',
    rescale = 'logical',
    sphere = 'logical',
    speed = 'NumericWithMin0Max3'
  ), prototype = list(
    speed = new('NumericWithMin0Max3', 1)
  )),
  contains = c('PropertySet', 'QTour')
)

Tour.meta$methods(
  initialize = function(...){
    callSuper(...)
  },
  pause = function() {
    timer$stop()
  },
  start = function() {
    timer$start()
  },
  slower = function() {
    aps <<- meta$aps * 0.9
  },
  faster = function() {
    aps <<- meta$aps * 1.1
  },
  setSpeed = function(ratio) {
    aps <<- aps.init * ratio
  },
  tour_init = function(){
    src <<- vapply(as.data.frame(data[, vars]), as.numeric, numeric(nrow(data)))
    if (rescale)
      src <<- tourr::rescale(src)
    if (sphere)
      src <<- tourr::sphere(src)
    tour <<- new_tour(src, tour_path, NULL)
    timer$interval <<- 1000 / fps
  },
  regSignal = function(){
    ## register singal here
    ## register signal
    ## meta$changed$connect(function(name) {
    ##   if (name != 'apsChanged') tour_init()
    ## })
    speedChanged$connect(function() setSpeed(speed))
  }
)
