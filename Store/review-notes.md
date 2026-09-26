# App Review notes

---

No account, login or network connection is required.

HOW TO USE: The Book tab lists items with the price you usually pay. Tap the green scan button in the middle of the bottom bar and point the camera at a product barcode. The first time, choose "Add a new item" and name it; after that the barcode opens the item. Type the price from the shelf tag and Pricebook shows a verdict (Stock up, Good price, Normal, Pricey, Fake sale) against the prices you logged before. "Save price" adds it to the book. The Check tab does the same without the camera, Compare works out which of several sizes or deals is cheapest per unit, and List sorts a shopping list by the store where each item is usually cheapest.

To see a full book straight away, the review video shows the app with sample data. In a fresh install the book starts empty; the quickest way to try it is Book > plus > name an item > log two or three prices at different stores, then Check a new price.

IN-APP PURCHASE: the app is free. One non-consumable, "Pricebook Pro" (com.mattbusel.pricebook.pro, $3.99), unlocks more than 30 items in the book, the six-month price history chart on each item page, and the CSV export. Scanning, verdicts, Check, Compare and the List are free. To see the paywall: open any item on the Book tab (the chart card reads "See the chart with Pro"), or open Settings (the gear on the Book tab) and tap "See Pro" or the CSV export. Restore purchase is on the paywall and in Settings under Pricebook Pro. No subscription.

PRIVACY: no data is collected. Items, prices and the list are stored in a JSON file in the app's Documents folder. The camera is used only while the scanner is open, only to read barcodes on the device with VisionKit; no images are stored or sent anywhere. The only network use is StoreKit, to buy or restore Pricebook Pro.

2. PURPOSE AND TARGET AUDIENCE
Pricebook is a personal grocery price book: shoppers record what they pay at the stores they use, and the app tells them whether a shelf price is a genuine deal, compares unit prices between sizes and multi-buy offers, and splits a shopping list by the cheapest store. General audience; rated 4+.

3. SETUP AND ACCESS
No setup, login or credentials. A new install starts with three generic stores (renamable in Settings, the gear on the Book tab) and an empty book.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
Apple StoreKit 2 for the one in-app purchase. No other network requests, no analytics, advertising or third-party frameworks. Built with SwiftUI, Swift Charts, StoreKit, VisionKit (DataScannerViewController for barcodes) and AVFoundation (camera permission status).

5. REGIONAL DIFFERENCES
None. Prices use the device's currency format; units include ounces, pounds, grams, kilograms, fluid ounces, millilitres, litres, quarts, gallons and counts.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. Store names in the sample data are ordinary supermarket names used only as labels a user would type; the app has no affiliation with any retailer and shows no retailer prices of its own. All art, text and code are my own work.
