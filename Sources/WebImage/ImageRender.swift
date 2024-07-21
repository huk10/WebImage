//
//  Created by vvgvjks on 2024/6/25.
//
//  Copyright © 2024 vvgvjks <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct ImageRender: View {
    let context: WebImage.Context
    @StateObject var binder: WebImage.Binder = .init()

    init(context: WebImage.Context) {
        self.context = context
    }

    @ViewBuilder
    private func renderedImage() -> some View {
        context.configurations
            .reduce(into: Image(uiImage: binder.loadedImage ?? .init())) { image, configure in
                image = configure(image)
            }
    }

    @ViewBuilder
    private func renderedPlaceholder() -> some View {
        if let placeholder = context.placeholder {
            placeholder(binder.progress)
        } else {
            Color.clear
        }
    }

    var body: some View {
        ZStack {
            renderedImage().opacity(binder.loaded ? 1.0 : 0.0)
            if binder.loadedImage == nil {
                ZStack {
                    renderedPlaceholder()
                }
                .onAppear { [weak binder = self.binder] in
                    guard let binder = binder else {
                        return
                    }
                    if binder.loadingOrSucceeded == false {
                        binder.start(context: context)
                    } else {
                        if context.reducePriorityOnDisappear && binder.loading {
                            binder.restorePriorityOnAppear()
                        }
                    }
                }
                .onDisappear { [weak binder = self.binder] in
                    guard let binder = binder else {
                        return
                    }
                    if context.cancelOnDisappear {
                        binder.cancel()
                    } else if context.reducePriorityOnDisappear {
                        binder.reducePriorityOnDisappear()
                    }
                }
            }
        }
        .animation(.easeInOut, value: binder.loaded)
    }
}
