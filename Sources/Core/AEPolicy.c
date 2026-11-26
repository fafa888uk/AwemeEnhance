#include "AEPolicy.h"
#include <math.h>
#include <stdint.h>
double AEClampRate(double v) { return isfinite(v) && v >= .25 && v <= 3 ? v : 1; }
double AEClampOpacity(double v) { return isfinite(v) && v >= .2 && v <= 1 ? v : 1; }
bool AEFilterItem(bool e, bool a, bool l, bool k, bool fa, bool fl, bool fk) {
    return e && ((a && fa) || (l && fl) || (k && fk));
}
size_t AEBestRendition(const double *b, const bool *s, size_t n) {
    size_t best = SIZE_MAX;
    if (!b || !s) return best;
    for (size_t i = 0; i < n; ++i)
        if (s[i] && isfinite(b[i]) && b[i] > 0 && (best == SIZE_MAX || b[i] > b[best])) best = i;
    return best;
}
bool AEDue(bool m, bool a, bool e, int now, int at, bool done) {
    return m && a && e && !done && now >= 0 && now < 1440 && at >= 0 && at < 1440 && now >= at;
}
