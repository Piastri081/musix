import Foundation

/// Royalty-free demo catalogue bundled with the app so it is playable the moment it launches.
/// Swap these for licensed catalogue URLs served by your backend before shipping.
enum DemoCatalog {

    static let tracks: [Track] = [
        Track(id: "t01",
              title: "Neon Tide",
              artist: "Vale",
              album: "Saltwater",
              duration: 372,
              genre: "Electronic",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
              palette: 0),

        Track(id: "t02",
              title: "Slow Motion",
              artist: "Kito Marsh",
              album: "After Hours",
              duration: 318,
              genre: "R&B",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
              palette: 1),

        Track(id: "t03",
              title: "Paper Planes",
              artist: "Ivory Hours",
              album: "Open Window",
              duration: 289,
              genre: "Indie",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
              palette: 2),

        Track(id: "t04",
              title: "Midnight Run",
              artist: "Sable",
              album: "No Signal",
              duration: 404,
              genre: "Hip-Hop",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
              palette: 3),

        Track(id: "t05",
              title: "Golden Hour",
              artist: "Lune",
              album: "Golden Hour",
              duration: 341,
              genre: "Pop",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
              palette: 4),

        Track(id: "t06",
              title: "Deep End",
              artist: "Romantic",
              album: "Static Bloom",
              duration: 267,
              genre: "Alt",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3",
              palette: 5),

        Track(id: "t07",
              title: "Blue Screen",
              artist: "Vale",
              album: "Saltwater",
              duration: 355,
              genre: "Electronic",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3",
              palette: 6),

        Track(id: "t08",
              title: "Hold That Thought",
              artist: "Kito Marsh",
              album: "After Hours",
              duration: 298,
              genre: "R&B",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3",
              palette: 7),

        Track(id: "t09",
              title: "Glass House",
              artist: "Ivory Hours",
              album: "Open Window",
              duration: 312,
              genre: "Indie",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3",
              palette: 2),

        Track(id: "t10",
              title: "Late Checkout",
              artist: "Sable",
              album: "No Signal",
              duration: 376,
              genre: "Hip-Hop",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3",
              palette: 3),

        Track(id: "t11",
              title: "Cassette Love",
              artist: "Lune",
              album: "Golden Hour",
              duration: 284,
              genre: "Pop",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3",
              palette: 4),

        Track(id: "t12",
              title: "Night Bus",
              artist: "Romantic",
              album: "Static Bloom",
              duration: 331,
              genre: "Alt",
              audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3",
              palette: 5)
    ]

    static let editorsPicks: [Track] = Array(tracks.prefix(6))
    static let lateNight: [Track] = tracks.filter { $0.genre == "R&B" || $0.genre == "Electronic" }
    static let fresh: [Track] = Array(tracks.suffix(6))
}
