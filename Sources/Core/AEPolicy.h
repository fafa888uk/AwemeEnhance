#pragma once
#include <stdbool.h>
#include <stddef.h>
double AEClampRate(double rate);
double AEClampOpacity(double opacity);
bool AEFilterItem(bool enabled, bool ads, bool live, bool keyword,
                  bool filterAds, bool filterLive, bool filterKeywords);
// Never invent a "supported" rendition: the adapter supplies capability evidence.
size_t AEBestRendition(const double *bitrates, const bool *supported, size_t count);
bool AEDue(bool master, bool authorized, bool friendEnabled, int minute,
           int scheduledMinute, bool handledToday);
