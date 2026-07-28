import SwiftUI
import StoreKit

/// 후원하기 — 아이스크림/커피/한끼 3종 소모성 후원.
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TipStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dgBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text("💝").font(.system(size: 46))
                            Text("개발자 응원하기")
                                .font(.system(size: 20, weight: .heavy)).foregroundStyle(Color.dgInk)
                            Text("보내주신 마음은 더 좋은 업데이트로 보답할게요!")
                                .font(.system(size: 14)).foregroundStyle(Color.dgSub)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        if store.isLoading {
                            ProgressView().controlSize(.large).tint(Color.dgAccent).padding(.top, 50)
                        } else if store.loadFailed {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 34)).foregroundStyle(Color.dgFaint)
                                Text("후원 항목을 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.")
                                    .font(.system(size: 14)).foregroundStyle(Color.dgSub)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 50)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.products, id: \.id) { product in
                                    tipRow(product)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 30)
                }
            }
            .navigationTitle("후원하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }.foregroundStyle(Color.dgAccent)
                }
            }
            .task { await store.load() }
            .alert("고맙습니다!", isPresented: $store.showThanks) {
                Button("천만에요") { }
            } message: {
                Text("따뜻한 응원 덕분에 일기곰이 더 자랍니다.")
            }
        }
    }

    private func tipRow(_ product: Product) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                Text(TipStore.emoji(for: product.id)).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.dgInk)
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.system(size: 12)).foregroundStyle(Color.dgSub)
                    }
                }
                Spacer()
                if store.purchasing == product.id {
                    ProgressView().controlSize(.small)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.dgAccent)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.dgCard))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.dgLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(store.purchasing != nil)
    }
}
