import 'package:flutter/material.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // List of all FAQs
  final List<Map<String, String>> _allFaqs = [
    {
      'question': 'How do I make a reservation?',
      'answer': 'To make a reservation, navigate to a restaurant page and click on the "Reserve" button. Select your preferred date, time, number of guests, and any special requests, then confirm your booking.'
    },
    {
      'question': 'Can I cancel my reservation?',
      'answer': 'Yes, you can cancel your reservation. Go to the Orders tab, find your reservation in the list, and tap the cancel button. Please note that some restaurants may have cancellation policies that apply.'
    },
    {
      'question': 'How can I update my profile information?',
      'answer': 'You can update your profile information by tapping on the edit icon on your profile page. Fill in the required information and save your changes.'
    },
    {
      'question': 'How do I write a review for a restaurant?',
      'answer': 'After you have visited a restaurant, go to the restaurant page or your past orders, and click on the "Write a Review" button. Rate your experience and share your feedback.'
    },
    {
      'question': 'What payment methods are accepted?',
      'answer': 'Greedy Bites supports various payment methods, including credit/debit cards, mobile wallets, and cash on delivery for food orders. Payment options may vary by restaurant.'
    },
    {
      'question': 'How can I find restaurants near me?',
      'answer': 'Use the Search tab and enable location services. You can filter restaurants by distance, cuisine type, price range, and more to find options near your location.'
    },
    {
      'question': 'What should I do if I encounter an issue with my order?',
      'answer': 'If you have an issue with your order, you can contact the restaurant directly through the app. Go to your order details and tap on the "Contact Restaurant" button. You can also reach out to our customer support team.'
    },
    {
      'question': 'How do I become a blogger on Greedy Bites?',
      'answer': 'To become a blogger on Greedy Bites, go to your profile settings and select "Become a Blogger". Fill out the application form with your writing samples and food expertise. Our team will review your application and get back to you.'
    },
    {
      'question': 'What are the criteria for restaurant ratings?',
      'answer': 'Restaurant ratings are based on user reviews, food quality, service, ambiance, and overall experience. Each aspect contributes to the final rating displayed on the restaurant page.'
    },
    {
      'question': 'Can I share restaurant recommendations with friends?',
      'answer': 'Yes, you can share restaurant recommendations with friends. On the restaurant page, tap the share icon to share the restaurant details via social media, messaging apps, or email.'
    }
  ];
  
  // Filtered FAQs based on search query
  List<Map<String, String>> _filteredFaqs = [];
  
  @override
  void initState() {
    super.initState();
    _filteredFaqs = _allFaqs;
    _searchController.addListener(_filterFaqs);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Filter FAQs based on search query
  void _filterFaqs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFaqs = _allFaqs;
      } else {
        _filteredFaqs = _allFaqs
            .where((faq) {
              return faq['question']!.toLowerCase().contains(query) || 
                     faq['answer']!.toLowerCase().contains(query);
            })
            .toList();
      }
    });
  }
  
  // Clear search query
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredFaqs = _allFaqs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          
          // Search results count
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Found ${_filteredFaqs.length} result${_filteredFaqs.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          
          // FAQ list
          Expanded(
            child: _filteredFaqs.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off, 
                        size: 64, 
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found for "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try using different keywords',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredFaqs.length,
                  itemBuilder: (context, index) {
                    final faq = _filteredFaqs[index];
                    return _buildFAQItem(
                      context, 
                      faq['question']!, 
                      faq['answer']!,
                      _searchQuery,
                    );
                  },
                ),
          ),
          
          // Contact support section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Still have questions?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement contact support functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support team will contact you shortly'),
                      ),
                    );
                  },
                  child: const Text('Contact Support'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(
    BuildContext context, 
    String question, 
    String answer, 
    String searchQuery,
  ) {
    // If no search query, show normal text
    if (searchQuery.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            Text(
              answer,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    // Highlight search matches in question and answer
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true, // Auto-expand when searching
        title: _highlightText(question, searchQuery),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          _highlightText(answer, searchQuery),
        ],
      ),
    );
  }
  
  // Highlight matching text in search results
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }
    
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int start = 0;
    int indexOfMatch;
    
    while (true) {
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
      if (indexOfMatch == -1) {
        // No more matches
        if (start < text.length) {
          spans.add(
            TextSpan(
              text: text.substring(start, text.length),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          );
        }
        break;
      }
      
      // Add non-matching text
      if (indexOfMatch > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, indexOfMatch),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        );
      }
      
      // Add matching text with highlight
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.yellow.shade200,
            color: Colors.black,
          ),
        ),
      );
      
      // Move to end of current match
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          color: Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }
} 