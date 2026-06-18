Product.create!(
  name: 'SendOwl E-Book: Mastering Rails',
  file_placeholder: 'https://example.com/downloads/mastering-rails.pdf',
  expiry_hours: 24,
  max_download_count: 3
)

Product.create!(
  name: 'Lattice Framework Source Code',
  file_placeholder: 'https://example.com/downloads/lattice-source.zip',
  expiry_hours: 48,
  max_download_count: 5
)

Product.create!(
  name: "5 Minute Test Stub",
  file_placeholder: "https://github.com/nicolaa/sendowl-clone/raw/main/test-stub.pdf",
  expiry_hours: 0.083333333333,
  max_download_count: 3
)

puts "Seeded #{Product.count} products."
