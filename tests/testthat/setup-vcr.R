# vcr configuration -----------------------------------------------------------
#
# HTTP interactions with the IUCN Red List API are replayed from the recorded
# cassettes in `_vcr/`, so the test suite never touches the network and never
# needs a real API key (CI has none).
#
# `rredlist` refuses to build a request when the key is an empty string, which
# would error before vcr ever sees the request, so we substitute a placeholder
# when no real key is set. The placeholder only ever has to satisfy that check:
# cassettes are matched on method + URI, not on credentials.
#
# To record a *new* cassette, set a real IUCN_REDLIST_KEY (e.g. in ~/.Renviron)
# and run the test once; vcr's default "once" record mode writes the missing
# cassette. 

if (requireNamespace("vcr", quietly = TRUE)) {
  if (!nzchar(Sys.getenv("IUCN_REDLIST_KEY"))) {
    Sys.setenv(IUCN_REDLIST_KEY = "iucn-redlist-key-not-required-for-playback")
  }

  vcr::vcr_configure(
    dir = testthat::test_path("_vcr")
  )
}
