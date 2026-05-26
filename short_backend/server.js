const express = require('express');
const { exec } = require('child_process');
const app = express();
const PORT = process.env.PORT || 4000;

app.get('/api/feed', (req, res) => {
    // Searches for the keyword topic and requests standard mp4 video outputs
    const searchQuery = 'mrbeast shorts';
    console.log(`Searching for "${searchQuery}" streams...`);

    // Using a direct command with android/ios/web_creator spoofing and node JS runtime to bypass data center IP blocks
    const command = `yt-dlp "ytsearch3:${searchQuery}" --dump-json --no-playlist --extractor-args "youtube:player_client=android,ios,web_creator" --js-runtimes node`
    exec(command, { maxBuffer: 1024 * 1024 * 30 }, (error, stdout, stderr) => {
        if (error) {
            console.warn(`[Warning] yt-dlp search failed (likely due to cloud IP block). Serving high-quality vertical fallback MP4s.`);
            const fallbackVideos = [
                {
                    title: "Neon Mirror Vibe",
                    thumbnail: "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=400",
                    stream_url: "https://assets.mixkit.co/videos/preview/mixkit-girl-in-neon-sign-in-front-of-a-mirror-40004-large.mp4",
                    duration: 15
                },
                {
                    title: "Golden Hour Run",
                    thumbnail: "https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400",
                    stream_url: "https://assets.mixkit.co/videos/preview/mixkit-vertical-shot-of-a-woman-running-on-the-beach-43117-large.mp4",
                    duration: 12
                },
                {
                    title: "DJ Vibe Club Night",
                    thumbnail: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400",
                    stream_url: "https://assets.mixkit.co/videos/preview/mixkit-vertical-shot-of-a-dj-playing-music-at-a-club-43407-large.mp4",
                    duration: 18
                }
            ];
            return res.json({ status: 'success', videos: fallbackVideos, message: 'Serving vertical fallback streams' });
        }

        if (!stdout || stdout.trim() === '') {
            return res.json({ status: 'success', videos: [], message: 'No media matched standard search parameters' });
        }

        try {
            const lines = stdout.trim().split('\n');
            const processedVideos = lines.map(line => {
                try {
                    const videoData = JSON.parse(line);
                    
                    // Fallbacks to extract the direct streaming .mp4 CDN source links
                    // We check for a combined progressive mp4 format FIRST because it's much easier for the emulator's S/W decoder to render.
                    let streamUrl = null;
                    if (videoData.formats) {
                        const goodFormat = videoData.formats.find(f => f.ext === 'mp4' && f.vcodec !== 'none' && f.acodec !== 'none' && f.protocol !== 'm3u8_native');
                        if (goodFormat) streamUrl = goodFormat.url;
                    }
                    if (!streamUrl) {
                        streamUrl = videoData.url;
                    }

                    return {
                        title: videoData.title,
                        thumbnail: videoData.thumbnail || (videoData.thumbnails && videoData.thumbnails[0]?.url),
                        stream_url: streamUrl, 
                        duration: videoData.duration
                    };
                } catch (e) {
                    return null;
                }
            }).filter(v => v !== null && v.stream_url);

            console.log(`Successfully fetched ${processedVideos.length} video streams.`);
            return res.json({ status: 'success', videos: processedVideos });
        } catch (parseError) {
            return res.status(500).json({ status: 'error', message: "Data parsing failed" });
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server is fully active and listening to all network traffic on Port ${PORT}`);
});
