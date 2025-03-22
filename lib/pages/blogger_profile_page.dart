import 'package:flutter/material.dart';
import '../models/blogger.dart';
import '../models/blog_post.dart';
import '../models/reel.dart';
import '../models/review.dart';
import '../services/blog_service.dart';
import '../services/review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class BloggerProfilePage extends StatefulWidget {
  final Blogger blogger;

  const BloggerProfilePage({
    super.key,
    required this.blogger,
  });

  @override
  State<BloggerProfilePage> createState() => _BloggerProfilePageState();
}

class _BloggerProfilePageState extends State<BloggerProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BlogPost> _posts = [];
  List<Reel> _reels = [];
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBloggerContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBloggerContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all content in parallel for better performance
      final futures = await Future.wait([
        BlogService.getBloggerPosts(widget.blogger.id),
        BlogService.getBloggerReels(widget.blogger.id),
        ReviewService.getBloggerReviews(widget.blogger.id),
      ]);

      if (mounted) {
        setState(() {
          _posts = futures[0] as List<BlogPost>;
          _reels = futures[1] as List<Reel>;
          _reviews = futures[2] as List<Review>;
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

  Future<void> _handleFollow() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to follow bloggers')),
        );
        return;
      }

      final isFollowing = widget.blogger.isFollowedBy(user.uid);

      setState(() {
        // Optimistically update the UI
        if (isFollowing) {
          widget.blogger.followers.remove(user.uid);
        } else {
          widget.blogger.followers.add(user.uid);
        }
      });

      if (isFollowing) {
        await BlogService.unfollowBlogger(widget.blogger.id, user.uid);
      } else {
        await BlogService.followBlogger(widget.blogger.id, user.uid);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing
                ? 'Unfollowed ${widget.blogger.name}'
                : 'Now following ${widget.blogger.name}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Revert the optimistic update on error
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          if (widget.blogger.isFollowedBy(user.uid)) {
            widget.blogger.followers.remove(user.uid);
          } else {
            widget.blogger.followers.add(user.uid);
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

  void _showFollowersList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bloggers')
            .doc(widget.blogger.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final followers = List<String>.from(data?['followers'] ?? []);

          if (followers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No followers yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Followers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final followerId = followers[index];
                    return FutureBuilder<UserModel?>(
                      future: UserService.getUserModel(followerId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(),
                            title: LinearProgressIndicator(),
                          );
                        }

                        final user = snapshot.data!;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.profileImageUrl != null
                                ? NetworkImage(user.profileImageUrl!)
                                : null,
                            child: user.profileImageUrl == null
                                ? Text(user.name[0].toUpperCase())
                                : null,
                          ),
                          title: Text(user.name),
                          subtitle: Text('@${user.username}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isFollowing = user != null && widget.blogger.isFollowedBy(user.uid);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.blogger.coverImageUrl != null
                ? Image.network(
                    widget.blogger.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  )
                : Container(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Icon(
                      Icons.restaurant,
                      size: 48,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: widget.blogger.profileImageUrl != null
                      ? NetworkImage(widget.blogger.profileImageUrl!)
                      : null,
                  backgroundColor: Colors.grey[200],
                  child: widget.blogger.profileImageUrl == null
                      ? Text(
                          widget.blogger.name.isNotEmpty
                              ? widget.blogger.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.blogger.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '@${widget.blogger.username}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _handleFollow,
                        icon: Icon(
                          isFollowing ? Icons.check : Icons.add,
                          size: 18,
                        ),
                        label: Text(isFollowing ? 'Following' : 'Follow'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.grey[200]
                              : Theme.of(context).primaryColor,
                          foregroundColor: isFollowing
                              ? Colors.black
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.blogger.bio?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      widget.blogger.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(
                        'Posts',
                        _posts.length,
                        null,
                      ),
                      _buildStatColumn(
                        'Reels',
                        _reels.length,
                        null,
                      ),
                      _buildStatColumn(
                        'Reviews',
                        _reviews.length,
                        null,
                      ),
                      _buildStatColumn(
                        'Followers',
                        widget.blogger.followers.length,
                        _showFollowersList,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.blogger.specialties.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Specialties',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.blogger.specialties.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.blogger.specialties[index],
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Reels'),
                  Tab(text: 'Reviews'),
                ],
              ),
            ),
            pinned: true,
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading content: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBloggerContent,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsGrid(),
                      _buildReelsGrid(),
                      _buildReviewsList(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return GestureDetector(
          onTap: () {
            // TODO: Navigate to post detail
          },
          child: post.imageUrl != null
              ? Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.article),
                ),
        );
      },
    );
  }

  Widget _buildReelsGrid() {
    if (_reels.isEmpty) {
      return const Center(child: Text('No reels yet'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reel = _reels[index];
        return GestureDetector(
          onTap: () {
            // TODO: Navigate to reel
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              reel.thumbnailUrl != null
                  ? Image.network(
                      reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black,
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
              const Positioned(
                right: 8,
                bottom: 8,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('No reviews yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => Icon(
                        index < review.rating.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      review.rating.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(review.comment),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(review.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
} 