class MockWorker {
  final String id;
  final String title;
  final String category;
  final int price;
  final double rating;
  final String providerName;
  final String location;
  final bool isAvailable;

  const MockWorker({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.rating,
    required this.providerName,
    required this.location,
    required this.isAvailable,
  });
}

const List<MockWorker> mockWorkersList = [
  MockWorker(id: 'W001', title: 'Expert Pipe & Leak Repair', category: 'Plumbing', price: 2500, rating: 4.8, providerName: 'Rashid Khan', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W002', title: 'Complete Wiring & UPS Setup', category: 'Electrical', price: 3500, rating: 4.6, providerName: 'Kamran Ali', location: 'Clifton', isAvailable: true),
  MockWorker(id: 'W003', title: 'Deep Home Cleaning', category: 'Cleaning', price: 1500, rating: 4.9, providerName: 'Usman Tariq', location: 'Johar', isAvailable: false),
  MockWorker(id: 'W004', title: 'AC Servicing & Gas Refill', category: 'AC Repair', price: 4500, rating: 4.7, providerName: 'Ali Raza', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W005', title: 'Custom Furniture Repair', category: 'Carpentry', price: 3000, rating: 4.5, providerName: 'Bilal Ahmed', location: 'DHA', isAvailable: true),
  MockWorker(id: 'W006', title: 'Bathroom Fixtures Fix', category: 'Plumbing', price: 2000, rating: 4.2, providerName: 'Zainab Bibi', location: 'Saddar', isAvailable: true),
  MockWorker(id: 'W007', title: 'Switchboard Installation', category: 'Electrical', price: 1200, rating: 4.4, providerName: 'Ahmed Farooq', location: 'Malir', isAvailable: false),
  MockWorker(id: 'W008', title: 'Split AC Installation', category: 'AC Repair', price: 5500, rating: 4.8, providerName: 'Faisal Qureshi', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W009', title: 'Sofa Shampoo & Wash', category: 'Cleaning', price: 2800, rating: 4.6, providerName: 'Saqib Mehmood', location: 'Clifton', isAvailable: true),
  MockWorker(id: 'W010', title: 'Door & Lock Replacement', category: 'Carpentry', price: 1800, rating: 4.1, providerName: 'Naveed Akhtar', location: 'Johar', isAvailable: true),
  MockWorker(id: 'W011', title: 'Generator Repair', category: 'Electrical', price: 4000, rating: 4.9, providerName: 'Rashid Khan', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W012', title: 'Water Tank Cleaning', category: 'Plumbing', price: 3500, rating: 4.3, providerName: 'Kamran Ali', location: 'DHA', isAvailable: false),
  MockWorker(id: 'W013', title: 'Window AC Service', category: 'AC Repair', price: 2000, rating: 4.5, providerName: 'Usman Tariq', location: 'Saddar', isAvailable: true),
  MockWorker(id: 'W014', title: 'Floor Polishing', category: 'Cleaning', price: 5000, rating: 4.7, providerName: 'Ali Raza', location: 'Malir', isAvailable: true),
  MockWorker(id: 'W015', title: 'Kitchen Cabinet Fix', category: 'Carpentry', price: 4200, rating: 4.8, providerName: 'Bilal Ahmed', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W016', title: 'Geyser Repair', category: 'Plumbing', price: 2500, rating: 4.6, providerName: 'Zainab Bibi', location: 'Clifton', isAvailable: false),
  MockWorker(id: 'W017', title: 'Ceiling Fan Installation', category: 'Electrical', price: 800, rating: 4.4, providerName: 'Ahmed Farooq', location: 'Johar', isAvailable: true),
  MockWorker(id: 'W018', title: 'Inverter AC Repair', category: 'AC Repair', price: 6000, rating: 5.0, providerName: 'Faisal Qureshi', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W019', title: 'Bathroom Deep Clean', category: 'Cleaning', price: 1500, rating: 4.2, providerName: 'Saqib Mehmood', location: 'DHA', isAvailable: true),
  MockWorker(id: 'W020', title: 'Wood Polish', category: 'Carpentry', price: 3200, rating: 4.5, providerName: 'Naveed Akhtar', location: 'Saddar', isAvailable: false),
  MockWorker(id: 'W021', title: 'Motor Pump Repair', category: 'Plumbing', price: 2800, rating: 4.7, providerName: 'Rashid Khan', location: 'Malir', isAvailable: true),
  MockWorker(id: 'W022', title: 'Short Circuit Fix', category: 'Electrical', price: 1500, rating: 4.8, providerName: 'Kamran Ali', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W023', title: 'Carpet Washing', category: 'Cleaning', price: 2200, rating: 4.3, providerName: 'Usman Tariq', location: 'Clifton', isAvailable: true),
  MockWorker(id: 'W024', title: 'AC Duct Cleaning', category: 'AC Repair', price: 3500, rating: 4.6, providerName: 'Ali Raza', location: 'Johar', isAvailable: false),
  MockWorker(id: 'W025', title: 'Bed Assembly', category: 'Carpentry', price: 2000, rating: 4.9, providerName: 'Bilal Ahmed', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W026', title: 'Sewerage Line Clearing', category: 'Plumbing', price: 4000, rating: 4.1, providerName: 'Zainab Bibi', location: 'DHA', isAvailable: true),
  MockWorker(id: 'W027', title: 'Main Panel Wiring', category: 'Electrical', price: 5500, rating: 4.5, providerName: 'Ahmed Farooq', location: 'Saddar', isAvailable: true),
  MockWorker(id: 'W028', title: 'Office Cleaning', category: 'Cleaning', price: 4500, rating: 4.8, providerName: 'Faisal Qureshi', location: 'Malir', isAvailable: false),
  MockWorker(id: 'W029', title: 'Fridge Gas Refill', category: 'AC Repair', price: 3800, rating: 4.7, providerName: 'Saqib Mehmood', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W030', title: 'Wardrobe Repair', category: 'Carpentry', price: 2600, rating: 4.4, providerName: 'Naveed Akhtar', location: 'Clifton', isAvailable: true),
  MockWorker(id: 'W031', title: 'Washing Machine Plumbing', category: 'Plumbing', price: 1200, rating: 4.6, providerName: 'Rashid Khan', location: 'Johar', isAvailable: true),
  MockWorker(id: 'W032', title: 'Solar Panel Setup', category: 'Electrical', price: 15000, rating: 5.0, providerName: 'Kamran Ali', location: 'Nazimabad', isAvailable: false),
  MockWorker(id: 'W033', title: 'Marble Grinding', category: 'Cleaning', price: 6000, rating: 4.2, providerName: 'Usman Tariq', location: 'DHA', isAvailable: true),
  MockWorker(id: 'W034', title: 'Heater Servicing', category: 'AC Repair', price: 1800, rating: 4.5, providerName: 'Ali Raza', location: 'Saddar', isAvailable: true),
  MockWorker(id: 'W035', title: 'Bookshelf Making', category: 'Carpentry', price: 7500, rating: 4.8, providerName: 'Bilal Ahmed', location: 'Malir', isAvailable: true),
  MockWorker(id: 'W036', title: 'Sink Blockage Removal', category: 'Plumbing', price: 1000, rating: 4.3, providerName: 'Zainab Bibi', location: 'Gulshan', isAvailable: false),
  MockWorker(id: 'W037', title: 'Chandelier Installation', category: 'Electrical', price: 2500, rating: 4.7, providerName: 'Ahmed Farooq', location: 'Clifton', isAvailable: true),
  MockWorker(id: 'W038', title: 'Window Cleaning', category: 'Cleaning', price: 1200, rating: 4.1, providerName: 'Faisal Qureshi', location: 'Johar', isAvailable: true),
  MockWorker(id: 'W039', title: 'Thermostat Replacement', category: 'AC Repair', price: 2200, rating: 4.6, providerName: 'Saqib Mehmood', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W040', title: 'Door Hinge Repair', category: 'Carpentry', price: 800, rating: 4.4, providerName: 'Naveed Akhtar', location: 'DHA', isAvailable: false),
  MockWorker(id: 'W041', title: 'Muslim Shower Fix', category: 'Plumbing', price: 600, rating: 4.9, providerName: 'Rashid Khan', location: 'Saddar', isAvailable: true),
  MockWorker(id: 'W042', title: 'Circuit Breaker Upgrade', category: 'Electrical', price: 3200, rating: 4.8, providerName: 'Kamran Ali', location: 'Malir', isAvailable: true),
  MockWorker(id: 'W043', title: 'Mattress Deep Cleaning', category: 'Cleaning', price: 2000, rating: 4.5, providerName: 'Usman Tariq', location: 'Gulshan', isAvailable: true),
  MockWorker(id: 'W044', title: 'AC Water Leakage Fix', category: 'AC Repair', price: 1500, rating: 4.7, providerName: 'Ali Raza', location: 'Clifton', isAvailable: false),
  MockWorker(id: 'W045', title: 'Dining Table Repair', category: 'Carpentry', price: 2800, rating: 4.2, providerName: 'Bilal Ahmed', location: 'Johar', isAvailable: true),
  MockWorker(id: 'W046', title: 'Underground Tank Repair', category: 'Plumbing', price: 5500, rating: 4.6, providerName: 'Zainab Bibi', location: 'Nazimabad', isAvailable: true),
  MockWorker(id: 'W047', title: 'CCTV Camera Setup', category: 'Electrical', price: 4000, rating: 4.9, providerName: 'Ahmed Farooq', location: 'DHA', isAvailable: true),
  MockWorker(id: 'W048', title: 'Post-Construction Clean', category: 'Cleaning', price: 8000, rating: 4.8, providerName: 'Faisal Qureshi', location: 'Saddar', isAvailable: false),
  MockWorker(id: 'W049', title: 'Compressor Replacement', category: 'AC Repair', price: 12000, rating: 5.0, providerName: 'Saqib Mehmood', location: 'Malir', isAvailable: true),
  MockWorker(id: 'W050', title: 'Wooden Flooring Fix', category: 'Carpentry', price: 6500, rating: 4.7, providerName: 'Naveed Akhtar', location: 'Gulshan', isAvailable: true),
];
