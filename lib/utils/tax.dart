const double kTaxRate = 0.15;

double taxOf(double inclusive) => inclusive * kTaxRate;

double baseOf(double inclusive) => inclusive * (1 - kTaxRate);
