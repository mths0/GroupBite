const double kTaxRate = 0.15;

double priceWithTax(double pretax) => pretax * (1 + kTaxRate);

double taxOf(double pretax) => pretax * kTaxRate;
