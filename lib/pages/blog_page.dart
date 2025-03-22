import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blogger.dart';
import '../models/blog_post.dart';
import '../models/reel.dart';
import '../services/blog_service.dart';
import 'package:video_player/video_player.dart';
import 'blogger_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Blogger> _bloggers = [];
  List<BlogPost> _feedPosts = [];
  List<Reel> _reels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = FirebaseAuth.instance.currentUser;

      // Get bloggers regardless of auth state
      final bloggers = await BlogService.getPopularBloggers();
      final reels = await BlogService.getReels();
      
      // Only get feed posts if user is authenticated
      List<BlogPost> feedPosts = [];
      if (user != null) {
        feedPosts = await BlogService.getFeedPosts(user.uid);
      }

      if (mounted) {
        setState(() {
          _bloggers = bloggers;
          _reels = reels;
          _feedPosts = feedPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFollow(Blogger blogger) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to follow bloggers')),
        );
        return;
      }

      final isFollowing = blogger.isFollowedBy(user.uid);

      setState(() {
        // Optimistically update the UI
        if (isFollowing) {
          blogger.followers.remove(user.uid);
        } else {
          blogger.followers.add(user.uid);
        }
      });

      if (isFollowing) {
        await BlogService.unfollowBlogger(blogger.id, user.uid);
      } else {
        await BlogService.followBlogger(blogger.id, user.uid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing
                ? 'Unfollowed ${blogger.name}'
                : 'Now following ${blogger.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Revert the optimistic update on error
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          if (blogger.isFollowedBy(user.uid)) {
            blogger.followers.remove(user.uid);
          } else {
            blogger.followers.add(user.uid);
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleReelFollow(String bloggerId, String bloggerName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to follow bloggers')),
        );
        return;
      }

      // Get the blogger data
      final blogger = await BlogService.getBlogger(bloggerId);
      if (blogger == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blogger not found')),
        );
        return;
      }

      final isFollowing = blogger.isFollowedBy(user.uid);

      if (isFollowing) {
        await BlogService.unfollowBlogger(bloggerId, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unfollowed $bloggerName')),
          );
        }
      } else {
        await BlogService.followBlogger(bloggerId, user.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Following $bloggerName')),
          );
        }
      }

      await _loadData(); // Refresh data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Blog'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'Reels'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExploreTab(),
                    _buildReelsTab(),
                  ],
                ),
    );
  }

  Widget _buildExploreTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading bloggers: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bloggers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No bloggers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to start sharing your food journey!',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  setState(() => _isLoading = true);
                  await BlogService.addSampleData();
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sample bloggers added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding sample data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Sample Bloggers'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _bloggers.length,
        itemBuilder: (context, index) {
          if (index < 0 || index >= _bloggers.length) {
            return const SizedBox.shrink(); // Return empty widget for invalid indices
          }
          return _buildBloggerGridCard(_bloggers[index]);
        },
      ),
    );
  }

  Widget _buildBloggerGridCard(Blogger blogger) {
    if (blogger == null) {
      return const SizedBox.shrink();
    }

    final user = FirebaseAuth.instance.currentUser;
    final isFollowing = user != null && blogger.followers.contains(user.uid);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BloggerProfilePage(blogger: blogger),
            ),
          ).then((_) => _loadData());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Image
            Stack(
              children: [
                SizedBox(
                  height: 80,
                  child: blogger.coverImageUrl != null
                      ? Image.network(
                          blogger.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        )
                      : Container(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                ),
                // Follow Button
                if (user != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleFollow(blogger),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isFollowing
                                ? Colors.white.withOpacity(0.9)
                                : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFollowing ? Icons.check : Icons.add,
                                size: 16,
                                color: isFollowing
                                    ? Theme.of(context).primaryColor
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isFollowing
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Profile Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Picture
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: blogger.profileImageUrl != null
                          ? NetworkImage(blogger.profileImageUrl!)
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: blogger.profileImageUrl == null
                          ? Text(
                              blogger.name.isNotEmpty
                                  ? blogger.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),

                    // Name
                    Text(
                      blogger.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Username
                    Text(
                      '@${blogger.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),

                    // Bio
                    if (blogger.bio?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        blogger.bio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],

                    // Stats
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip(
                          icon: Icons.article,
                          count: blogger.stats['posts'] ?? 0,
                          label: 'Posts',
                        ),
                        _buildStatChip(
                          icon: Icons.video_library,
                          count: blogger.stats['reels'] ?? 0,
                          label: 'Reels',
                        ),
                        _buildStatChip(
                          icon: Icons.people,
                          count: blogger.followers.length,
                          label: 'Followers',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 2),
        Text(
          count.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildReelsTab() {
    // Create placeholder reels if none exist
    final reelsToShow = _reels.isEmpty
        ? List.generate(
            5,
            (index) => Reel(
              id: 'placeholder_$index',
              userId: 'user_$index',
              userName: 'Food Blogger ${index + 1}',
              userImage: 'https://picsum.photos/200?random=$index',
              videoUrl: 'https://example.com/video$index.mp4',
              thumbnailUrl: 'https://picsum.photos/400/600?random=$index',
              description: 'Delicious food reel #${index + 1}\n#foodie #cooking #delicious',
              createdAt: DateTime.now().subtract(Duration(days: index)),
              likes: [],
              tags: ['food', 'delicious', 'cooking'],
              metadata: {'type': 'reel'},
            ),
          )
        : _reels;

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: reelsToShow.length,
      itemBuilder: (context, index) {
        final reel = reelsToShow[index];
        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Reel Background/Thumbnail
              reel.thumbnailUrl != null
                  ? Image.network(
                      reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Icon(
                        Icons.movie,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Content
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info and description
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User info row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                // Get the blogger data
                                final blogger = await BlogService.getBlogger(reel.userId);
                                if (blogger != null && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BloggerProfilePage(blogger: blogger),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(reel.userImage),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    reel.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('bloggers')
                                  .doc(reel.userId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final user = FirebaseAuth.instance.currentUser;
                                final data = snapshot.data!.data() as Map<String, dynamic>?;
                                final followers = List<String>.from(data?['followers'] ?? []);
                                final isFollowing = user != null && followers.contains(user.uid);

                                return TextButton(
                                  onPressed: () => _handleReelFollow(reel.userId, reel.userName),
                                  style: TextButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.white.withOpacity(0.1)
                                        : Theme.of(context).primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Description
                        Text(
                          reel.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action buttons on right
              Positioned(
                right: 16,
                bottom: 100,
                child: Column(
                  children: [
                    // Like button
                    _buildActionButton(
                      icon: Icons.favorite,
                      label: '${reel.likes.length}',
                      isActive: reel.likes.contains(FirebaseAuth.instance.currentUser?.uid),
                      onTap: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please sign in to like reels')),
                          );
                          return;
                        }
                        try {
                          if (reel.likes.contains(user.uid)) {
                            await BlogService.unlikeReel(reel.id, user.uid);
                          } else {
                            await BlogService.likeReel(reel.id, user.uid);
                          }
                          await _loadData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Comment button
                    _buildActionButton(
                      icon: Icons.comment,
                      label: '0',
                      onTap: () {
                        // TODO: Show comments sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Comments coming soon!')),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Share button
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: () {
                        // TODO: Implement sharing
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sharing coming soon!')),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Book table button
                    _buildActionButton(
                      icon: Icons.restaurant,
                      label: 'Book',
                      onTap: () {
                        // TODO: Implement restaurant booking
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restaurant booking coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Play button overlay
              Center(
                child: IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: () {
                    // TODO: Implement video playback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video playback coming soon!')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.red : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BlogPost post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(post.userImage),
            ),
            title: Text(post.userName),
            subtitle: Text(
              _formatTimestamp(post.createdAt),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),

          // Post Image
          if (post.imageUrl != null)
            Image.network(
              post.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

          // Post Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(post.content),
          ),

          // Post Actions
          Row(
            children: [
              IconButton(
                icon: Icon(
                  post.likes.contains(FirebaseAuth.instance.currentUser?.uid)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.red,
                ),
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  if (post.likes.contains(user.uid)) {
                    await BlogService.unlikePost(post.id, user.uid);
                  } else {
                    await BlogService.likePost(post.id, user.uid);
                  }
                  await _loadData();
                },
              ),
              Text('${post.likes.length}'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () {
                  // TODO: Implement comments
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  // TODO: Implement sharing
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 