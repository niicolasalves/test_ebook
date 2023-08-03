import 'dart:async';
import 'dart:developer';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Testing eBooks Reader'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late EpubBook ebook;
  Completer epubCompleter = Completer();
  List<Page> pages = [];

  double fontSize = 14;

  @override
  void initState() {
    super.initState();

    fetchBook();
  }

  Future<void> fetchBook() async {
    log('loading ebook');
    var response = await http.get(Uri.parse('https://filesamples.com/samples/ebook/epub/Alices%20Adventures%20in%20Wonderland.epub'));

    if (response.statusCode == 200) {
      ebook = await EpubReader.readBook(response.bodyBytes);
      // var spines = ebook.Schema!.Package!.Spine!.Items!
      //     .map((item) => ebook.Schema!.Package!.Manifest!.Items!.where((element) => element.Id == item.IdRef).first)
      //     .toList();

      var chapters = ebook.Chapters ?? [];

      for (var next in chapters) {
        var page = ebook.Content!.AllFiles![next.ContentFileName];
        if (page is EpubTextContentFile) {
          final file = dom.Document.html(page.Content!);
          var documentBody = file.getElementsByTagName('body').first.children;
          documentBody = removeAllDiv(documentBody);

          pages.add(Page(
            fileName: page.FileName,
            paragraphs: documentBody.map((e) => Paragraph(e, documentBody.indexOf(e))).toList(),
          ));
        }
      }
    }

    epubCompleter.complete();
  }

  List<dom.Element> removeAllDiv(List<dom.Element> elements) {
    final List<dom.Element> result = [];

    for (final node in elements) {
      if ((node.localName == 'div' || node.localName == 'blockquote') && node.children.length > 1) {
        result.addAll(removeAllDiv(node.children));
      } else {
        result.add(node);
      }
    }

    return result;
  }

  void increaseFontSize() {
    setState(() {
      fontSize++;
    });
  }

  void decreaseFontSize() {
    setState(() {
      fontSize--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return FutureBuilder(
                  future: epubCompleter.future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return CustomScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const PageScrollPhysics(),
                      slivers: pages
                          .cast<Page>()
                          .map((e) => SliverToBoxAdapter(
                                child: Wrap(
                                  direction: Axis.vertical,
                                  children: e.paragraphs
                                      .map(
                                        (w) => SizedBox(
                                          width: constraints.maxWidth,
                                          child: Html(
                                            data: w.element.outerHtml,
                                            style: {'p': Style(fontSize: FontSize(fontSize))},
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ))
                          .toList(),
                    );
                  });
            }),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: decreaseFontSize,
                child: const Icon(Icons.text_decrease),
              ),
              ElevatedButton(
                onPressed: increaseFontSize,
                child: const Icon(Icons.text_increase),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class Paragraph {
  Paragraph(this.element, this.paragraphIndex, [this.pageIndex = 0]);

  final dom.Element element;
  final int paragraphIndex;
  final int pageIndex;
}

class Page {
  String? fileName;
  List<Paragraph> paragraphs;

  Page({required this.fileName, required this.paragraphs});
}
